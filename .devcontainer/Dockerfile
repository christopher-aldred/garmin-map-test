# Use Ubuntu as base image
FROM ubuntu:22.04

# Avoid prompts from apt
ENV DEBIAN_FRONTEND=noninteractive

# Set working directory
WORKDIR /workspace

# Update package list and install in stages to identify issues
RUN apt-get update && apt-get upgrade -y

# Install basic utilities
RUN apt-get install -y \
    wget \
    curl \
    git \
    unzip \
    zip \
    tar \
    ca-certificates \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install build essentials
RUN apt-get update && apt-get install -y \
    build-essential \
    gcc \
    g++ \
    make \
    cmake \
    autoconf \
    automake \
    libtool \
    pkg-config \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Java
RUN apt-get update && apt-get install -y \
    openjdk-17-jdk \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Python
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install GDAL and geographic tools
RUN apt-get update && apt-get install -y \
    gdal-bin \
    libgdal-dev \
    python3-gdal \
    libexpat1-dev \
    zlib1g-dev \
    libbz2-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Python packages needed for phyghtmap
RUN apt-get update && apt-get install -y \
    python3-matplotlib \
    python3-bs4 \
    python3-numpy \
    python3-pil \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install osmium-tool (osmosis might not be available)
RUN apt-get update && apt-get install -y \
    osmium-tool \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install additional utilities
RUN apt-get update && apt-get install -y \
    imagemagick \
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

# Upgrade pip and downgrade setuptools for compatibility
RUN pip3 install --upgrade pip \
    && pip3 install setuptools==68.0.0 wheel

# Install Python packages for data processing
RUN pip3 install --no-cache-dir \
    requests \
    beautifulsoup4 \
    lxml \
    numpy \
    matplotlib \
    osmium \
    pyproj \
    pillow

# Install phyghtmap from official source (latest version with numpy fix)
RUN wget http://katze.tfiu.de/projects/phyghtmap/phyghtmap_2.24.orig.tar.gz \
    && tar -xzf phyghtmap_2.24.orig.tar.gz \
    && cd phyghtmap-2.24 \
    && pip3 install . \
    && cd / \
    && rm -rf phyghtmap-2.24 phyghtmap_2.24.orig.tar.gz

# Clone freizeitkarte style for reference
RUN git clone https://github.com/freizeitkarte/freizeitkarte.git /opt/freizeitkarte

# Create directories for data storage
RUN mkdir -p /workspace/data/osm \
    /workspace/data/dem \
    /workspace/data/output \
    /workspace/scripts

# Create helper scripts
RUN echo '#!/bin/bash\njava -Xmx4g -jar /opt/mkgmap/mkgmap.jar "$@"' > /usr/local/bin/mkgmap \
    && echo '#!/bin/bash\njava -Xmx4g -jar /opt/splitter/splitter.jar "$@"' > /usr/local/bin/splitter \
    && chmod +x /usr/local/bin/mkgmap /usr/local/bin/splitter

# Set environment variables
ENV OSM_DATA_DIR=/workspace/data/osm
ENV DEM_DATA_DIR=/workspace/data/dem
ENV OUTPUT_DIR=/workspace/data/output

# Reset frontend
ENV DEBIAN_FRONTEND=dialog

# Default command
CMD ["/bin/bash"]
