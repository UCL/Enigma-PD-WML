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

## UNet-pgs Docker Image

This pipeline builds on the [UNet-pgs Docker Image](https://hub.docker.com/r/wmhchallenge/pgs) created
to accompany the paper ['White matter hyperintensities segmentation using the ensemble U-Net with
multi-scale highlighting foregrounds'](https://www.sciencedirect.com/science/article/pii/S1053811921004171).

UNet-pgs is not distributed under a published licence. Hosung Kim, an author of UNet-pgs, has granted
permission for UNet-pgs to be used, incorporated and redistributed as part of this pipeline for
academic and other non-commercial research purposes, free of charge. Any commercial use or
redistribution requires separate permission from the UNet-pgs authors, and must also comply with the
licensing terms of bundled third-party software, including FSL.
