# ZORBA Splat Studio

**A high-performance 3D Gaussian Splatting trainer and viewer.**

> This is a modified fork of [LichtFeld Studio](https://github.com/MrNeRF/LichtFeld-Studio) by MrNeRF and contributors. All original copyright notices and the GPLv3 license are preserved in full. See [LICENSE](LICENSE) and [THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md).

[![License](https://img.shields.io/badge/License-GPLv3-green.svg)](LICENSE)
[![CUDA](https://img.shields.io/badge/CUDA-12.8+-76B900?logo=nvidia&logoColor=white)](https://developer.nvidia.com/cuda-downloads)
[![C++](https://img.shields.io/badge/C++-23-00599C?logo=cplusplus&logoColor=white)](https://en.cppreference.com/w/cpp/23)

---

## What This Is

ZORBA Splat Studio is a pure C++23/CUDA training and viewing application for 3D Gaussian Splatting. No Python in the training loop. No PyTorch. Direct GPU memory management with a custom CUDA Adam optimizer. It trains 3DGS models from COLMAP output and exports standard `.ply` files.

It is the training and QC component of the **ZORBA Splat** pipeline:

> **COLMAP** (Structure-from-Motion) -> **ZORBA Splat Studio** (Train + View) -> `.ply` -> [**ZORBA Splat UE**](https://github.com/AniketMan/ZorbaSplatUE) (Render in Unreal Engine)

## Key Capabilities

- **2.4x faster rasterization** than the original Inria 3DGS implementation
- **Two rasterizer backends**: FastGS rasterizer and a full gsplat CUDA port, selectable at runtime
- **MCMC and ADC optimization strategies** for improved convergence
- **Custom CUDA Adam optimizer** with no PyTorch dependency
- **Bilateral grid appearance modeling** for handling per-image color variation
- **Real-time interactive viewer** with OpenGL rendering during and after training
- **8GB VRAM minimum** for training (no PyTorch memory overhead)
- **PLY viewer mode**: Open any existing `.ply` Gaussian Splat file for inspection without training

## Requirements

- **OS**: Windows 10/11 or Linux
- **GPU**: NVIDIA with CUDA 12.8+ support
- **Driver**: NVIDIA driver version 570 or newer
- **For building from source**: Visual Studio 2022, CMake 3.30+, vcpkg, C++23 compiler (GCC 14+ or MSVC 17.10+)

## Quick Start (Pre-Built Binary)

Pre-built Windows binaries are available from the upstream LichtFeld Studio project. These are fully compatible with ZORBA Splat Studio until fork-specific builds are published:

1. Download the latest release from the [LichtFeld Studio releases page](https://github.com/MrNeRF/LichtFeld-Studio/releases)
2. Unzip the archive
3. Run the executable in the `bin/` folder
4. No compilation necessary. Requires NVIDIA driver 570+.

## Building from Source

A PowerShell build script is included that handles all dependencies automatically:

```powershell
# Clone the repo
git clone https://github.com/AniketMan/ZorbaSplatStudio.git
cd ZorbaSplatStudio

# Run the one-shot build script (handles vcpkg, LibTorch, submodules, CMake)
.\build_lichtfeld.ps1 -Configuration Release
```

The build script will:

1. Verify prerequisites (Visual Studio 2022, CUDA 12.8+, CMake, Git)
2. Set up vcpkg and install all dependencies
3. Download LibTorch (used only for LPIPS evaluation metrics)
4. Initialize git submodules
5. Configure and build with CMake + Ninja

The output binary will be in the `build/` directory.

### VS Code

The `.vscode/` directory includes `launch.json` and `settings.json` for debugging with `cuda-gdb`. Open the repo folder in VS Code, build via the CMake extension or the PowerShell script, and use the provided launch configurations.

## Usage

### Training

```bash
# Train from COLMAP output
./LichtFeld-Studio -d /path/to/colmap/output --output-path /path/to/output --strategy mcmc

# Train with specific image subfolder and Gaussian cap
./LichtFeld-Studio -d /path/to/data --images images_4 --strategy mcmc --max-cap 2500000
```

### Viewing a PLY File

```bash
# Open an existing .ply for viewing
./LichtFeld-Studio --view /path/to/point_cloud.ply
```

### Exporting

Training automatically exports a `point_cloud.ply` to your output directory. This file is directly importable into **ZORBA Splat UE** by dragging it into the UE5 Content Browser.

## The ZORBA Splat Pipeline

| Stage | Tool | Output |
|-------|------|--------|
| Capture | Camera (photos or video) | Images |
| SfM | COLMAP (global mapper) | Sparse reconstruction |
| Training | **ZORBA Splat Studio** | `.ply` Gaussian Splat |
| QC | **ZORBA Splat Studio** (viewer) | Visual inspection |
| Rendering | [**ZORBA Splat UE**](https://github.com/AniketMan/ZorbaSplatUE) | Real-time in Unreal Engine |

## Upstream Community & Support

This fork benefits from the active LichtFeld Studio community:

- [Discord Community](https://discord.gg/TbxJST2BbC) - Get help, share results, and discuss development
- [LichtFeld Studio Wiki](https://github.com/MrNeRF/LichtFeld-Studio/wiki/) - Documentation
- [Awesome 3D Gaussian Splatting](https://mrnerf.github.io/awesome-3D-gaussian-splatting/) - Comprehensive paper list

## Attribution

This software is a modified fork of **LichtFeld Studio**, originally created by Janusch Patas (MrNeRF) and contributors. The original project and its contributors are credited in full. This fork retains the GPLv3 license as required.

- Original project: [https://github.com/MrNeRF/LichtFeld-Studio](https://github.com/MrNeRF/LichtFeld-Studio)
- Original authors: LichtFeld Studio Authors (see LICENSE)
- Original sponsor: [Core 11](https://www.core11.eu/)

If you use this software in research, please cite the original project:

```bibtex
@software{lichtfeld2025,
  author    = {LichtFeld Studio},
  title     = {A high-performance C++ and CUDA implementation of 3D Gaussian Splatting},
  year      = {2025},
  url       = {https://github.com/MrNeRF/LichtFeld-Studio}
}
```

## License

This project is licensed under the **GNU General Public License v3.0 (GPLv3)**. See [LICENSE](LICENSE) for the full text.
