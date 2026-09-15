# Third-Party Notices

The source code in this repository is licensed under the BSD 3-Clause License (see [LICENSE](LICENSE)).

## FSL (FMRIB Software Library)

This pipeline requires [FSL](https://fsl.fmrib.ox.ac.uk/fsl/docs/), Copyright (C) University of
Oxford, to run. Most of FSL is available free of charge for non-commercial and academic research use only.

Commercial use of FSL requires a separate paid licence from Oxford University Innovation (OUI)
(contact `fsl@innovation.ox.ac.uk`). See the
[FSL licence page](https://fsl.fmrib.ox.ac.uk/fsl/docs/license.html) for the full terms and the
definition of commercial use.

Because this pipeline cannot run without FSL, the pipeline as a whole is subject to this
restriction. Users and redistributors are responsible for their own compliance with FSL's
licence terms.

## Other dependencies

- This pipeline build on the [UNet-pgs Docker Image](https://hub.docker.com/r/wmhchallenge/pgs) created
  to accompany the paper ['White matter hyperintensities segmentation using the ensemble U-Net with multi-scale highlighting foregrounds'](https://www.sciencedirect.com/science/article/pii/S1053811921004171). There is no licensing information provided for this image. Please contact the authors of the paper for any questions regarding its use.
- [Nipoppy](https://github.com/nipoppy/nipoppy) is not a strict dependency but is recommended for
  converting your dataset into BIDS format. `Nipoppy` is released under the
  [MIT Licence](https://github.com/nipoppy/nipoppy/blob/main/LICENSE).
