/* SPDX-FileCopyrightText: 2025 LichtFeld Studio Authors
 *
 * SPDX-License-Identifier: GPL-3.0-or-later */

/**
 * @file fast_rasterizer.hpp
 * @brief High-performance differentiable Gaussian rasterizer for training
 *
 * This file defines the interface to the FastGS rasterization backend, which
 * provides 2.4x faster rendering compared to the original Inria 3DGS implementation.
 *
 * ## Rasterization Pipeline Overview
 *
 * The differentiable rasterizer performs both forward (rendering) and backward
 * (gradient computation) passes. The pipeline is:
 *
 * ```
 * FORWARD PASS:
 * ┌─────────────┐   ┌──────────────┐   ┌─────────────┐   ┌───────────┐
 * │ 3D Gaussians│ → │ Project to 2D│ → │ Tile Sorting│ → │ Rasterize │ → Image
 * │ (pos,cov,sh)│   │ (screen space)│  │ (depth order)│  │ (α-blend) │
 * └─────────────┘   └──────────────┘   └─────────────┘   └───────────┘
 *
 * BACKWARD PASS:
 * ┌───────────┐   ┌──────────────┐   ┌─────────────────┐   ┌──────────────┐
 * │ dL/dImage │ → │ dL/dGaussian │ → │ dL/dCovariance  │ → │ dL/dPosition │
 * │ (from loss)│   │ (per-pixel)  │   │ dL/dSH, dL/dα   │   │ dL/dScale    │
 * └───────────┘   └──────────────┘   └─────────────────┘   └──────────────┘
 * ```
 *
 * ## Key Performance Optimizations
 *
 * 1. **Tile-based rendering**: Screen is divided into 16x16 tiles. Each tile
 *    only processes Gaussians that overlap it, reducing wasted work.
 *
 * 2. **GPU radix sort**: Gaussians are sorted by depth per-tile using highly
 *    optimized CUB radix sort. This enables correct alpha blending order.
 *
 * 3. **Shared memory caching**: Gaussian data is loaded into shared memory
 *    once per tile, then reused across all pixels in the tile.
 *
 * 4. **Early termination**: Pixel threads stop accumulating when alpha reaches
 *    saturation (>0.9999), avoiding unnecessary Gaussian evaluations.
 *
 * 5. **Coalesced memory access**: Data layout is optimized for GPU memory
 *    coalescing patterns, maximizing memory bandwidth utilization.
 *
 * ## Memory Requirements
 *
 * The rasterizer allocates intermediate buffers for:
 * - Projected 2D Gaussians (~64 bytes per Gaussian)
 * - Per-tile Gaussian lists (~4 bytes per tile-Gaussian intersection)
 * - Sort keys and values (~16 bytes per Gaussian)
 *
 * For 2.5M Gaussians at 1080p: ~500MB VRAM for rasterization buffers alone.
 *
 * ## Usage
 *
 * ```cpp
 * // Forward pass - render image and save context for backward
 * auto [render_output, ctx] = fast_rasterize_forward(splat_data, camera, params);
 *
 * // Compute loss gradient
 * auto d_image = compute_loss_gradient(render_output.image, target_image);
 *
 * // Backward pass - compute gradients w.r.t. Gaussian parameters
 * fast_rasterize_backward(ctx, d_image, splat_data);
 *
 * // Gradients are now in splat_data.grad_* fields, ready for optimizer
 * ```
 *
 * @see gsplat_rasterizer.hpp for the alternative gsplat backend
 * @see trainer.hpp for how rasterization fits into the training loop
 *
 * @author LichtFeld Studio Authors
 * @author Aniket Bhatt (ZORBA fork modifications)
 */

#pragma once

#include "core/camera.hpp"
#include "core/splat_data.hpp"
#include "optimizer/adam_optimizer.hpp"
#include "optimizer/render_output.hpp"
#include <expected>
#include <rasterization_api.h>
#include <string>

namespace lfs::training {
    // Forward pass context - holds intermediate buffers needed for backward
    struct FastRasterizeContext {
        lfs::core::Tensor image;
        lfs::core::Tensor alpha;
        lfs::core::Tensor bg_color; // Saved for alpha gradient computation

        // Gaussian parameters (saved to avoid re-fetching in backward)
        lfs::core::Tensor means;
        lfs::core::Tensor raw_scales;
        lfs::core::Tensor raw_rotations;
        lfs::core::Tensor raw_opacities;
        lfs::core::Tensor shN;

        const float* w2c_ptr = nullptr;
        const float* cam_position_ptr = nullptr;

        // Forward context (contains buffer pointers, frame_id, etc.)
        fast_lfs::rasterization::ForwardContext forward_ctx;

        int active_sh_bases;
        int total_bases_sh_rest;
        int width;
        int height;
        float focal_x;
        float focal_y;
        float center_x;
        float center_y;
        float near_plane;
        float far_plane;
        bool mip_filter = false;

        // Tile information (for tile-based training)
        int tile_x_offset = 0; // Horizontal offset of this tile
        int tile_y_offset = 0; // Vertical offset of this tile
        int tile_width = 0;    // Width of this tile (0 = full image)
        int tile_height = 0;   // Height of this tile (0 = full image)

        // Background image for per-pixel blending (optional, empty = use bg_color)
        lfs::core::Tensor bg_image;
    };

    // Explicit forward pass - returns render output and context for backward
    // Optional tile parameters for memory-efficient training (tile_width/height=0 means full image)
    // bg_image is optional - if provided, uses per-pixel background blending instead of solid color
    std::expected<std::pair<RenderOutput, FastRasterizeContext>, std::string> fast_rasterize_forward(
        lfs::core::Camera& viewpoint_camera,
        lfs::core::SplatData& gaussian_model,
        lfs::core::Tensor& bg_color,
        int tile_x_offset = 0,
        int tile_y_offset = 0,
        int tile_width = 0,
        int tile_height = 0,
        bool mip_filter = false,
        const lfs::core::Tensor& bg_image = {});

    // Backward pass with optional extra alpha gradient for masked training
    void fast_rasterize_backward(
        const FastRasterizeContext& ctx,
        const lfs::core::Tensor& grad_image,
        lfs::core::SplatData& gaussian_model,
        AdamOptimizer& optimizer,
        const lfs::core::Tensor& grad_alpha_extra = {},
        const lfs::core::Tensor& pixel_error_map = {});

    // Convenience wrapper for inference (no backward needed)
    inline RenderOutput fast_rasterize(
        lfs::core::Camera& viewpoint_camera,
        lfs::core::SplatData& gaussian_model,
        lfs::core::Tensor& bg_color) {
        auto result = fast_rasterize_forward(viewpoint_camera, gaussian_model, bg_color);
        if (!result) {
            throw std::runtime_error(result.error());
        }
        return result->first;
    }
} // namespace lfs::training
