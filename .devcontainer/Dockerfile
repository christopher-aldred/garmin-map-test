# Use Ubuntu as base image
FROM ubuntu:22.04

# Avoid prompts from apt
ENV DEBIAN_FRONTEND=noninteractive

# Set working directory
WORKDIR /workspace

# Install system dependencies
RUN apt-get update && apt-get install -y \
    # Basic utilities
    wget \
    curl \
    git \
    unzip \
    zip \
    tar \
    # Build essentials
    build-essential \
    gcc \
    g++ \
    make \
    cmake \
    autoconf \
    automake \
    libtool \
    pkg-config \
    # Java (required for mkgmap and splitter)
    openjdk-17-jdk \
    # Python for scripting
    python3 \
    python3-pip \
    python3-dev \
    # Geographic data processing
    gdal-bin \
    libgdal-dev \
    python3-gdal \
    osmosis \
    osmium-tool \
    # Additional geo libraries
    libosmium2-dev \
    libexpat1-dev \
    zlib1g-dev \
    libbz2-dev \
    # Image processing (for map styling)
    imagemagick \
    # Text processing
    sed \
    awk \
    # Clean up
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Set Java environment
ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
ENV PATH="${JAVA_HOME}/bin:${PATH}"

# Install mkgmap (OSM to Garmin converter)
RUN wget https://www.mkgmap.org.uk/download/mkgmap-latest.tar.gz \
    && tar -xzf mkgmap-latest.tar.gz \
    && rm mkgmap-latest.tar.gz \
    && mv mkgmap-* /opt/mkgmap \
    && ln -s /opt/mkgmap/mkgmap.jar /usr/local/bin/mkgmap.jar

# Install splitter (for splitting large OSM files)
RUN wget https://www.mkgmap.org.uk/download/splitter-latest.tar.gz \
    && tar -xzf splitter-latest.tar.gz \
    && rm splitter-latest.tar.gz \
    && mv splitter-* /opt/splitter \
    && ln -s /opt/splitter/splitter.jar /usr/local/bin/splitter.jar

# Install phyghtmap (for DEM to OSM contour conversion)
RUN pip3 install --no-cache-dir phyghtmap

# Install additional Python packages for data processing
RUN pip3 install --no-cache-dir \
    requests \
    beautifulsoup4 \
    lxml \
    numpy \
    matplotlib \
    osmium \
    pyproj

# Create directories for data storage
RUN mkdir -p /workspace/data/osm \
    /workspace/data/dem \
    /workspace/data/output \
    /workspace/scripts

# Create helper scripts
RUN echo '#!/bin/bash\njava -jar /opt/mkgmap/mkgmap.jar "$@"' > /usr/local/bin/mkgmap \
    && echo '#!/bin/bash\njava -jar /opt/splitter/splitter.jar "$@"' > /usr/local/bin/splitter \
    && chmod +x /usr/local/bin/mkgmap /usr/local/bin/splitter

# Set environment variables
ENV OSM_DATA_DIR=/workspace/data/osm
ENV DEM_DATA_DIR=/workspace/data/dem
ENV OUTPUT_DIR=/workspace/data/output

# Reset frontend
ENV DEBIAN_FRONTEND=dialog

# Default command
CMD ["/bin/bash"]