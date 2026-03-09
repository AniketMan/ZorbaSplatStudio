# ZORBA Splat Studio - Source Code Architecture

This document provides an overview of the codebase structure and key components.

## Directory Structure

```
src/
├── app/              # Application entry point, CLI parsing, main window
├── core/             # Core data structures and utilities
│   ├── camera.hpp        # Camera representation (intrinsics, extrinsics)
│   ├── scene.hpp         # Scene graph (cameras, splat data, transforms)
│   ├── splat_data.hpp    # Gaussian splat data storage (positions, SH, etc.)
│   ├── tensor.hpp        # GPU tensor wrapper (CUDA memory management)
│   └── cuda/             # CUDA utilities (memory arena, stream management)
│
├── training/         # Training pipeline
│   ├── trainer.hpp       # Main training orchestrator
│   ├── strategies/       # Densification strategies
│   │   ├── mcmc.hpp          # MCMC-based optimization
│   │   └── adc.hpp           # Adaptive Density Control
│   ├── optimizer/        # Adam optimizer (pure CUDA, no PyTorch)
│   ├── rasterization/    # Differentiable GPU rasterizers
│   │   ├── fast_rasterizer.hpp   # FastGS backend (2.4x faster)
│   │   └── gsplat_rasterizer.hpp # gsplat backend (reference)
│   ├── losses/           # Loss functions (L1, SSIM, D-SSIM)
│   ├── kernels/          # CUDA kernels for training operations
│   └── metrics/          # Evaluation metrics (PSNR, SSIM, LPIPS)
│
├── rendering/        # Real-time OpenGL viewer
│   ├── rendering_engine.hpp  # Main rendering pipeline
│   ├── shader_manager.hpp    # GLSL shader compilation
│   └── cuda_gl_interop.hpp   # CUDA <-> OpenGL buffer sharing
│
├── io/               # File I/O
│   ├── exporter.hpp      # PLY export
│   └── colmap_loader.hpp # COLMAP import
│
├── geometry/         # Geometric utilities
├── visualizer/       # UI panels and debug visualization
└── python/           # Python plugin system
```

## Key Concepts

### 1. SplatData (core/splat_data.hpp)

The fundamental data structure holding all Gaussian parameters:

```cpp
struct SplatData {
    Tensor positions;     // [N, 3] float32 - 3D positions
    Tensor scales;        // [N, 3] float32 - log-scale (exp() to get actual)
    Tensor rotations;     // [N, 4] float32 - quaternions
    Tensor opacities;     // [N, 1] float32 - sigmoid input (sigmoid() to get actual)
    Tensor sh_dc;         // [N, 3] float32 - DC spherical harmonics (base color)
    Tensor sh_rest;       // [N, K, 3] float32 - higher-order SH coefficients
};
```

### 2. Training Loop (training/trainer.cpp)

The main training iteration:

```
for each iteration:
    1. Sample random training image
    2. Rasterize Gaussians from that camera viewpoint (forward pass)
    3. Compute photometric loss (L1 + D-SSIM)
    4. Backpropagate through rasterizer (backward pass)
    5. Apply densification strategy (MCMC or ADC)
    6. Update parameters with Adam optimizer
    7. Log metrics, save checkpoint if needed
```

### 3. Differentiable Rasterization

The magic that makes gradient-based optimization possible:

**Forward pass**: Project 3D Gaussians to 2D, sort by depth, alpha-blend to image
**Backward pass**: Compute ∂L/∂position, ∂L/∂scale, ∂L/∂rotation, ∂L/∂opacity, ∂L/∂SH

Two backends are available:
- **FastGS**: Optimized for speed (2.4x faster than reference)
- **gsplat**: More features, closer to original paper

### 4. Densification Strategies

Control how Gaussians are added/removed during training:

**MCMC** (Markov Chain Monte Carlo):
- Treats Gaussian placement as sampling problem
- Uses Langevin dynamics for exploration
- Better convergence, fewer hyperparameters

**ADC** (Adaptive Density Control):
- Original 3DGS approach
- Splits/clones based on gradient magnitude
- Prunes based on opacity threshold

## Memory Management

All GPU memory is managed through `core::cuda::MemoryArena`:

- Pre-allocates large contiguous blocks
- Sub-allocates without CUDA API calls
- Avoids fragmentation during MCMC (frequent add/remove)
- Typical usage: 8GB VRAM minimum for training

## Threading Model

```
┌─────────────────┐     ┌─────────────────┐
│   UI Thread     │     │ Training Thread │
│  (OpenGL, ImGui)│     │   (CUDA, Adam)  │
└────────┬────────┘     └────────┬────────┘
         │                       │
         │    shared mutex       │
         ├───────────────────────┤
         │                       │
         ▼                       ▼
    ┌─────────────────────────────────┐
    │         SplatData               │
    │  (GPU tensors, read by viewer,  │
    │   written by trainer)           │
    └─────────────────────────────────┘
```

## Building

See the main README.md for build instructions. Key requirements:
- CUDA 12.8+
- C++23 compiler (GCC 14+ or MSVC 17.10+)
- CMake 3.30+
- vcpkg for dependencies

## Adding New Features

1. **New loss function**: Add to `training/losses/`, implement backward pass
2. **New densification strategy**: Inherit from `IStrategy` in `training/strategies/`
3. **New file format**: Add loader in `io/`, register in Scene
4. **New visualization**: Add panel in `visualizer/`

## References

- [3D Gaussian Splatting](https://repo-sam.inria.fr/fungraph/3d-gaussian-splatting/) - Original paper
- [3DGS as MCMC](https://ubc-vision.github.io/3dgs-mcmc/) - MCMC strategy paper
- [gsplat](https://github.com/nerfstudio-project/gsplat) - Reference CUDA kernels
- [LichtFeld Studio](https://github.com/MrNeRF/LichtFeld-Studio) - Upstream project
