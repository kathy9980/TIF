# TIF: Time-series-based Image Fusion

Welcome to the **TIF** repository! This package includes the source code and examples of the **Time-series-based Image Fusion (TIF)** algorithm. The TIF algorithm was developed to produce 10 m Harmonized Landsat and Sentinel-2 (HLS) data by fusing 30 m Landsat 8 and 10 m Sentinel-2 time series.

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Installation](#installation)
- [Usage](#usage)
- [Examples](#examples)
- [Contributing](#contributing)
- [Acknowledgements](#acknowledgements)

## Overview

The TIF algorithm is designed to enhance the spatial resolution of Landsat 8 imagery from 30 m to 10 m by leveraging the higher resolution Sentinel-2 data. This method can be used to generate fine-resolution dense time series, i.e. 10 m Harmonized Landsat and Sentinel-2 (HLS) data.

## Features

- **Spatial Resolution Enhancement:** Improve Landsat 8 imagery resolution from 30 m to 10 m on any given date.
- **Pixel-level Sensor-to-sensor Adjustment:** Harmonize data from different satellite sources without bandpass adjustment.
- **Robust Performance:** Demonstrated robustness to temporal changes and varying land cover types.
- **Parallel Computing Support:** Accelerated by using massive computing cores.

## Installation

To install the TIF package, you can clone the repository and ensure you have the required MATLAB toolboxes: [Mapping Toolbox](https://www.mathworks.com/products/mapping.html) and [Statistics and Machine Learning Toolbox](https://www.mathworks.com/products/statistics.html).


```bash
git clone https://github.com/yourusername/TIF.git
```

## Usage
To use the TIF algorithm, follow these steps:

1. Prepare your Landsat 8 and Sentinel-2 time series data.
2. Conduct the TIF algorithm to obtain TIF coefficient for each spectral band.
3. Use the TIF coefficients to fuse the Landsat data and produce 10 m HLS time series.

Here's an example script to get you started:

## Examples
We have included several examples in the examples directory to demonstrate the usage of the TIF algorithm. These examples cover different scenarios and use cases, helping you understand how to apply the algorithm to your own data.

### Example 1: Basic Usage 
This example demonstrates the basic usage of the TIF algorithm on a single pixel.
```matlab
addpath(genpath('path_to_TIF_functions')); 

%% Load example data
data = load('Examples/Data/T18TXM_r03007c09955.mat');
L8_metadata = load('Examples/Data/L8_metadata.mat');
S2_metadata = load('Examples/Data/S2_metadata.mat');

%% Initialize the TIF algorithm 
TIF_coefficient = runTIFSinglePixel(data, L8_metadata, S2_metadata, 'do_plot', true);

%% Run the fusion process to the time series
[clrx_L, prediction, clrx_S, clry_S] = predictClearSurfaceReflectanceTS(data, TIF_coefficient);

%% Merge Sentinel-2 and the predction values
[clrx_HLS, HLS_10m] = mergeL10S10TimeSeries(clrx_S, clry_S, clrx_L, prediction);

%% Display the results
band_plot = 6; 
plot10mHLSTimeSeries(clrx_S, clry_S, clrx_L, prediction, band_plot);
```


### Example 2: Advanced Usage
This example shows advanced usage with additional options and parameters.
```
```

### Example 3. TIF HPC usage
This example shows how to perform the TIF algorithm with imagery time series (spatial range: 6 km by 6 km) on UConn HPC.
```
```

## Contributing
We welcome contributions to the TIF project! If you would like to contribute, please follow these steps:

1. Fork the repository.
2. Create a new branch for your feature or bugfix.
3. Commit your changes and push the branch to your fork.
4. Submit a pull request to the main repository.

## Acknowledgement
Reference:


If you have any questions, please contact Zhe Zhu (zhe@uconn.edu) and Kexin Song (kexin.song@uconn.edu) at Department of Natural Resources and the Environment, University of Connecticut.



