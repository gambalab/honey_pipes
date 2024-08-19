# $ git clone https://github.com/gambalab/honey_pipes
# $ cd honey_pipes
# $ sudo docker build -f ./Dockerfile -t honey_tools .

# Stage miniconda envs
FROM continuumio/miniconda3:latest AS conda_setup
RUN conda config --add channels defaults && \
    conda config --add channels bioconda && \
    conda config --add channels conda-forge

RUN conda create -y -n bio \
                    bioconda::bcftools=1.20 \
                    bioconda::samtools=1.20 \
                    bioconda::tabix=0.2.6 \
                    bioconda::sambamba=1.0.1 \
		    bioconda::bbmap=39.06 \
		    && conda clean -a

RUN conda create -y -n pod5 \
    && conda init \
    && . ~/.bashrc \
    && conda activate pod5 \
    && conda install -y pip \
    && pip install pod5 \
    && conda deactivate \
    && conda clean -a

# Stage cuda ubuntu base
FROM nvidia/cuda:12.6.0-runtime-ubuntu24.04 AS base
FROM base AS base-amd64

COPY --from=conda_setup /opt/conda /opt/conda

ENV NV_CUDNN_VERSION=9.3.0.75-1
ENV NV_CUDNN_PACKAGE_NAME=libcudnn9-cuda-12
ENV NV_CUDNN_PACKAGE=libcudnn9-cuda-12=${NV_CUDNN_VERSION}

FROM base AS base-arm64

ENV NV_CUDNN_VERSION=9.3.0.75-1
ENV NV_CUDNN_PACKAGE_NAME=libcudnn9-cuda-12
ENV NV_CUDNN_PACKAGE=libcudnn9-cuda-12=${NV_CUDNN_VERSION}
FROM base-${TARGETARCH}

ARG TARGETARCH

LABEL maintainer="https://github.com/gambalab/honey_pipes/issues"
LABEL com.nvidia.cudnn.version="${NV_CUDNN_VERSION}"

RUN apt-get update && apt-get install -y --no-install-recommends \
    ${NV_CUDNN_PACKAGE} \
    wget \
    build-essential \
    libboost-all-dev \
    libgtest-dev \
    && apt-mark hold ${NV_CUDNN_PACKAGE_NAME} \
    && apt-get autoremove \ 
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Include dorado
RUN wget -qO- https://cdn.oxfordnanoportal.com/software/analysis/dorado-0.7.3-linux-x64.tar.gz | tar -xvz -C /opt
RUN mv /opt/dorado-0.7.3-linux-x64 /opt/dorado
WORKDIR /opt/dorado/models
RUN /opt/dorado/bin/dorado download --model all

# Copying DRAGMAP source code and build
COPY ./DRAGMAP /opt/dragmap_src
ENV HAS_GTEST=0
ENV STATIC=1
WORKDIR /opt/dragmap_src
RUN make -j4

# Copying minimap2 source code and build
COPY ./minimap2 /opt/minimap_src
WORKDIR /opt/minimap_src
RUN make -j4

# Copy bin files
WORKDIR /opt/bin
COPY ./scripts/*.sh .
RUN cp /opt/dragmap_src/build/release/dragen-os .
RUN cp /opt/dragmap_src/build/release/compare .
RUN cp /opt/minimap_src/minimap2 .
RUN chmod +x /opt/bin/*

# clear source files
RUN rm -rf /opt/minimap_src /opt/dragmap_src/

ENV PATH="${PATH}":/opt/conda/bin:/opt/conda/envs/bio/bin:/opt/conda/envs/pod5/bin:/opt/bin:/opt/dorado/bin
