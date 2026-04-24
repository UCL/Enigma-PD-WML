# Developer docs

## Setup instructions

After installing the necessary [dependencies](../README.md#1-install-prerequisites), you
will need to clone this repository from GitHub and move into the `Enigma-PD-WML` directory:

```bash
git clone https://github.com/UCL-ARC/Enigma-PD-WML.git
cd Enigma-PD-WML
```

### Building the Docker Image

You can build the image with the following command:

```bash
cd Enigma-PD-WML
docker build -f Dockerfile -t enigma-pd-wml .
```

### Building the Apptainer Image

If you want to run the container via Apptainer, you can convert this Docker image into an Apptainer one via:

```bash
docker image save enigma-pd-wml -o enigma-pd-wml.tar
apptainer build enigma-pd-wml.sif docker-archive:enigma-pd-wml.tar
```

### Running the pipeline with Docker

After building the Docker image, you can run a container based on this local image:

```bash
docker run -v "${PWD}"/data:/data enigma-pd-wml
```

Note, this requires your BIDS data is stored in the directory `Enigma-PD-WML/data`.

### Running the pipeline with Apptainer

After building the Apptainer image, you can run a container based on this local image:

```bash
apptainer run --bind "${PWD}"/data:/data enigma-pd-wml.sif
```

Note, this requires your BIDS data is stored in the directory `Enigma-PD-WML/data`, and that `enigma-pd-wml.sif`
is in the `Enigma-PD-WML` directory.

## Making new releases to docker hub

This repository has a github actions workflow to automate uploading to
[Docker Hub](https://hub.docker.com/r/hamiedaharoon24/enigma-pd-wml/tags) when a new release is made on github.

- Go to [the releases tab](https://github.com/UCL-ARC/Enigma-PD-WML/releases) and click 'Draft a new release'.

- Click 'Choose a tag' and enter a new version number e.g. `v1.0.0`

- Click 'Generate release notes'. This will add a summary of any commits since the last release.

- Click the green 'Publish release' button at the bottom left.

- This will trigger the action to run and upload the code on the `main` branch to Docker Hub and Sylabs Cloud. Note: as
  the images are very large, this will take a while! (around 40 minutes)

## Linting setup (pre-commit)

This repository has another github actions workflow to run various linting checks on pull requests / commits to `main`.
This uses [`pre-commit`](https://pre-commit.com/), a python based tool. The enabled checks can be seen/updated in the
[pre-commit configuration file](https://github.com/UCL-ARC/Enigma-PD-WML/blob/main/.pre-commit-config.yaml).

Some of the main ones used are:

- [hadolint](https://github.com/hadolint/hadolint): for linting Dockerfiles
- [shellcheck](https://www.shellcheck.net/): for linting shell scripts

It can be useful to run `pre-commit` locally to catch issues early. To do so, you will need to have python installed
locally (for example, by installing [Miniforge](https://github.com/conda-forge/miniforge) or similar)

Then run:

```bash
pip install pre-commit
```

Then (from inside a local clone of this github repository), run:

```bash
pre-commit install
```

`pre-commit` should now run automatically every time you `git commit`, flagging any issues.

## Some notes on the Dockerfile

There are two main components to the Dockerfile:

- The requirements for UNets-pgs
- The requirements for FSL

All requirements for the UNets-pgs workflow come from the
[base pgs image](https://hub.docker.com/r/cvriend/pgs/tags), including the bash script and packages like tensorflow.
Note: this uses quite old versions of python (2.7) and other packages.

FSL is installed via conda, as [specified in the FSL docs](https://fsl.fmrib.ox.ac.uk/fsl/docs/install/conda.html). We
install Miniforge as our conda distribution, then install the specific `fsl` packages used by the enigma-pd-wml workflow
as listed in the `environment.yml` file. This file also contains some additional python dependencies required by the
`png_generator.py` script for the QC workflow.

By installing FSL in this way, we reduce the overall size of the docker image - as we only install the pieces of FSL we
need to use. Alternate installation methods (e.g.
[via fslinstaller.py](https://fsl.fmrib.ox.ac.uk/fsl/docs/install/container.html)) require installation of the entirety
of FSL, giving less flexibility.

If you want to find out which FSL conda package versions correspond to a particular FSL release, see the
[FSL release docs](https://fsl.fmrib.ox.ac.uk/fsl/docs/development/management/fsl_releases.html) and specifically their
[manifest repo](https://git.fmrib.ox.ac.uk/fsl/conda/manifest/). The manifest repo has tags for all main FSL releases,
with the `yml` files stating corresponding conda package versions.
