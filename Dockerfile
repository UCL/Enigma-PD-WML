FROM cvriend/pgs:latest
WORKDIR /

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    wget \
    bc \
    dc \
    tree \
    parallel \
    zip && \
    rm -rf /var/lib/apt/lists/*

# Install miniforge
RUN wget -O Miniforge3.sh "https://github.com/conda-forge/miniforge/releases/download/26.1.1-3/Miniforge3-26.1.1-3-Linux-x86_64.sh"
RUN bash Miniforge3.sh -b -p "/conda"
ENV PATH="$PATH:/conda/bin"

# Install python dependencies including FSL
COPY environment.yml .
RUN conda env create --file environment.yml

# Set FSL environment variables
ENV FSLENV=enigma_pd_wml_env
ENV FSLDIR=/conda/envs/${FSLENV}
ENV PATH=${FSLDIR}/share/fsl/bin:${PATH}

COPY src .
RUN mkdir /data

RUN chmod +x analysis_script.sh

ENTRYPOINT ["/analysis_script.sh"]
