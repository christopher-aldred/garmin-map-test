#!/bin/bash

# UK Garmin Map Builder with DEM Data
# This script downloads UK OSM data and DEM data, then creates a Garmin map file

set -e  # Exit on error

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="${DATA_DIR:-$SCRIPT_DIR/data}"
OSM_DIR="$DATA_DIR/osm"
DEM_DIR="$DATA_DIR/dem"
OUTPUT_DIR="$DATA_DIR/output"
WORK_DIR="$DATA_DIR/work"

# Map configuration
MAP_NAME="${MAP_NAME:-UK_Topo}"
MAP_ID="${MAP_ID:-63240001}"
FAMILY_ID="${FAMILY_ID:-6324}"

# UK bounding box (approximate)
UK_BBOX="49.9:2.5:60.9:-8.0"  # min_lat:max_lon:max_lat:min_lon

# Create directories
mkdir -p "$OSM_DIR" "$DEM_DIR" "$OUTPUT_DIR" "$WORK_DIR"

echo "========================================="
echo "UK Garmin Map Builder"
echo "========================================="
echo ""

# Step 1: Download UK OSM data
echo "[1/6] Downloading UK OpenStreetMap data..."
OSM_FILE="$OSM_DIR/great-britain-latest.osm.pbf"

if [ ! -f "$OSM_FILE" ]; then
    echo "Downloading from Geofabrik..."
    wget -O "$OSM_FILE" \
        "https://download.geofabrik.de/europe/great-britain-latest.osm.pbf"
    echo "Download complete: $(du -h "$OSM_FILE" | cut -f1)"
else
    echo "OSM file already exists, skipping download."
    echo "Delete $OSM_FILE to force re-download."
fi

# Step 2: Download DEM data
echo ""
echo "[2/6] Downloading DEM (elevation) data..."
echo "Using SRTM data via phyghtmap (will auto-download)..."

# Generate contour lines from DEM data
CONTOUR_FILE="$DEM_DIR/uk_contours.osm"

if [ ! -f "$CONTOUR_FILE" ]; then
    echo "Generating contour lines (20m intervals)..."
    phyghtmap \
        --max-nodes-per-tile=0 \
        --source=view3 \
        --step=20 \
        --line-cat=400,100 \
        --simplify=5 \
        --start-node-id=20000000000 \
        --start-way-id=10000000000 \
        --write-timestamp \
        --output-prefix="$DEM_DIR/uk" \
        --pbf \
        --area=$UK_BBOX
    
    # Find the generated file
    GENERATED_CONTOUR=$(ls -t "$DEM_DIR"/uk_*.osm.pbf 2>/dev/null | head -1)
    if [ -f "$GENERATED_CONTOUR" ]; then
        mv "$GENERATED_CONTOUR" "$DEM_DIR/uk_contours.osm.pbf"
        CONTOUR_FILE="$DEM_DIR/uk_contours.osm.pbf"
        echo "Contours generated: $(du -h "$CONTOUR_FILE" | cut -f1)"
    else
        echo "Warning: No contour file generated, continuing without elevation data"
        CONTOUR_FILE=""
    fi
else
    echo "Contour file already exists, skipping generation."
fi

# Step 3: Merge OSM and contour data
echo ""
echo "[3/6] Merging map and elevation data..."
MERGED_FILE="$WORK_DIR/uk_merged.osm.pbf"

if [ -n "$CONTOUR_FILE" ] && [ -f "$CONTOUR_FILE" ]; then
    osmium merge "$OSM_FILE" "$CONTOUR_FILE" -o "$MERGED_FILE"
    echo "Merged file created: $(du -h "$MERGED_FILE" | cut -f1)"
else
    echo "Skipping merge, using OSM data only..."
    cp "$OSM_FILE" "$MERGED_FILE"
fi

# Step 4: Split the data
echo ""
echo "[4/6] Splitting data into tiles..."
cd "$WORK_DIR"

if [ ! -f "$WORK_DIR/63240001.osm.pbf" ]; then
    splitter \
        --max-nodes=1000000 \
        --mapid=$MAP_ID \
        --output=pbf \
        "$MERGED_FILE"
    echo "Splitting complete."
else
    echo "Split files already exist, skipping split."
fi

# Step 5: Create style file for mkgmap
echo ""
echo "[5/6] Creating map style..."

# Create a basic style directory
STYLE_DIR="$WORK_DIR/style"
mkdir -p "$STYLE_DIR"

# Create options file for better map rendering
cat > "$WORK_DIR/mkgmap_options.args" << 'EOF'
# General options
family-id: 6324
product-id: 1
series-name: UK Topo Map
family-name: UK OSM Maps
area-name: United Kingdom

# Map features
latin1
lower-case
make-all-cycleways
link-pois-to-ways
add-pois-to-areas
generate-sea=extend-sea-sectors
draw-priority: 25
transparent

# Routing options
route
drive-on-left
check-roundabouts
add-boundary-nodes-at-admin-boundaries=2

# Index options
index
housenumbers
road-name-config: roadNameConfig

# Address search
location-autofill=is_in,nearest

# Performance
max-jobs

# Contour settings
style-file: contours
EOF

# Create simple contours style
mkdir -p "$STYLE_DIR/contours"
cat > "$STYLE_DIR/contours/version" << 'EOF'
1
EOF

cat > "$STYLE_DIR/contours/lines" << 'EOF'
# Contour lines
contour=elevation & contour_ext=elevation_minor { name '${ele|conv:m=>ft}'; } [0x20 resolution 23]
contour=elevation & contour_ext=elevation_medium { name '${ele|conv:m=>ft}'; } [0x21 resolution 21]
contour=elevation & contour_ext=elevation_major { name '${ele|conv:m=>ft}'; } [0x22 resolution 20]
EOF

cat > "$STYLE_DIR/contours/points" << 'EOF'
# Contour points/peaks
natural=peak [0x6616 resolution 20]
EOF

echo "Style files created."

# Step 6: Build the Garmin map
echo ""
echo "[6/6] Building Garmin map file..."

mkgmap \
    --style-file="$STYLE_DIR" \
    -c "$WORK_DIR/mkgmap_options.args" \
    --mapname=$MAP_ID \
    --description="$MAP_NAME" \
    --country-name="United Kingdom" \
    --country-abbr="UK" \
    --output-dir="$OUTPUT_DIR" \
    --gmapsupp \
    $WORK_DIR/6324*.osm.pbf

# Check if map was created
if [ -f "$OUTPUT_DIR/gmapsupp.img" ]; then
    MAP_SIZE=$(du -h "$OUTPUT_DIR/gmapsupp.img" | cut -f1)
    echo ""
    echo "========================================="
    echo "SUCCESS! Map created successfully!"
    echo "========================================="
    echo ""
    echo "Map file: $OUTPUT_DIR/gmapsupp.img"
    echo "Size: $MAP_SIZE"
    echo ""
    echo "To install on your Garmin watch:"
    echo "1. Connect your watch via USB"
    echo "2. Copy gmapsupp.img to /GARMIN/ folder"
    echo "3. Safely eject and restart your watch"
    echo ""
else
    echo "ERROR: Map file was not created!"
    exit 1
fi

# Optional: Create additional formats
echo "Creating named map file..."
cp "$OUTPUT_DIR/gmapsupp.img" "$OUTPUT_DIR/${MAP_NAME}.img"

echo ""
echo "Build complete! Files available in: $OUTPUT_DIR"
ls -lh "$OUTPUT_DIR"/*.img