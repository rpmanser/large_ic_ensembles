# large_ic_ensembles

This repository contains scripts that were used to produce the results for the paper titled "Large initial condition convection-allowing ensembles for probabilistic prediction of convective hazards" by Russell P. Manser and Brian C. Ancell, submitted to Monthly Weather Review.

Please note that scripts for reproducing EnKF ICs are not included.

## Contents

- `ensemble_stat/`: scripts to run the MET `ensemble_stat` tool.
- `post/`: scripts to post-process WRF ensemble forecasts.
- `run_ensemble/`: scripts to create WRF IC/BCs and run ensemble forecasts.
- `verify/`: scripts to verify ensemble probabilistic convective forecasts.

## Requirements

Some requirements will need to be installed by the user, while others may be provided by a module loading system on a high-performance computing system. Below, we list the software we used from Texas Tech University's High Performance Computing Center, followed by software we installed ourselves, and finally the Python environment that we used.

### Provided by HPC

- Intel compilers
- MPI compiled with intel (impi)
- netCDF4
- HDF5
- singularity (if MET is installed via a singularity container)
- [nco 4.7.3](http://nco.sourceforge.net/)

### Installed by the user

- [WRF-ARW version 3.5.1](https://www2.mmm.ucar.edu/wrf/users/download/get_source.html)
- [Model Evaluation Tools version 8.0](https://dtcenter.org/community-code/model-evaluation-tools-met)
- [DART Lanai](https://dart.ucar.edu/software/) (only required for reproducing EnKF TTU and EnKF GFS ICs)
- [pigz](http://www.zlib.net/pigz/) (not required, but usually makes zipping/unzipping faster)

### Python environment for neighborhood verification

Python was used to post-process all forecasts and verify probabilistic forecasts of convective hazards. The requirements are specified in `requirements_neighborhood.txt`. To install the Python environment, do the following:

1. Download and install [Miniconda](https://docs.conda.io/en/latest/miniconda.html).

1. Create a conda environment called `ens`:

		conda create -n ens --file requirements.txt

	Then activate the environment:

		source activate ens

1. Download and install [`wrf-ens-tools`](https://github.com/ac0015/wrf-ens-tools). You can clone the repo with

		git clone https://github.com/ac0015/wrf-ens-tools.git

	Change directories into `wrf-ens-tools`, then run

		pip install .


### Python environment for MET pre-processing

Python was also used to format data for the requirements of MET version 8.0. This requires a separate Python environment installation, specified by `requirements_met.txt`. To isntall the Python environment, do the following:

1. Download and install [Miniconda](https://docs.conda.io/en/latest/miniconda.html) (if have not already).

1. Create a conda environment called `met`:

    conda create -n met --file requirements_met.txt
