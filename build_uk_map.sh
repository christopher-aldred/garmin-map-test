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
# Format: min_lat:min_lon:max_lat:max_lon
UK_BBOX_PHYGHTMAP="49.9:-8.0:60.9:2.5"  # For phyghtmap
UK_BBOX_OSMIUM="49.9,2.5,60.9,-8.0"     # For osmium (if needed)

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
echo "SKIPPING DEM generation for now (can be enabled later)"
CONTOUR_FILE=""

# Uncomment below to enable DEM contours:
# echo "Using SRTM data via phyghtmap (will auto-download)..."
# CONTOUR_FILE="$DEM_DIR/uk_contours.osm"
# 
# if [ ! -f "$CONTOUR_FILE" ]; then
#     echo "Generating contour lines (20m intervals)..."
#     phyghtmap \
#         --max-nodes-per-tile=0 \
#         --source=view3 \
#         --step=20 \
#         --line-cat=400,100 \
#         --start-node-id=20000000000 \
#         --start-way-id=10000000000 \
#         --write-timestamp \
#         --output-prefix="$DEM_DIR/uk" \
#         --pbf \
#         --area=$UK_BBOX_PHYGHTMAP
#     
#     # Find the generated file
#     GENERATED_CONTOUR=$(ls -t "$DEM_DIR"/uk_*.osm.pbf 2>/dev/null | head -1)
#     if [ -f "$GENERATED_CONTOUR" ]; then
#         mv "$GENERATED_CONTOUR" "$DEM_DIR/uk_contours.osm.pbf"
#         CONTOUR_FILE="$DEM_DIR/uk_contours.osm.pbf"
#         echo "Contours generated: $(du -h "$CONTOUR_FILE" | cut -f1)"
#     else
#         echo "Warning: No contour file generated, continuing without elevation data"
#         CONTOUR_FILE=""
#     fi
# else
#     echo "Contour file already exists, skipping generation."
# fi

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
    echo "This may take 15-30 minutes for UK data..."
    splitter \
        --max-nodes=1200000 \
        --max-threads=4 \
        --mapid=$MAP_ID \
        --output=pbf \
        --write-kml="$WORK_DIR/areas.kml" \
        "$MERGED_FILE"
    
    # Count the number of tiles created
    TILE_COUNT=$(ls -1 $WORK_DIR/6324*.osm.pbf 2>/dev/null | wc -l)
    echo "Splitting complete. Created $TILE_COUNT tiles."
else
    echo "Split files already exist, skipping split."
fi

# Step 5: Create style file for mkgmap
echo ""
echo "[5/6] Preparing map configuration..."

# Note: Using default mkgmap style (no custom style needed for basic maps)

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

# Routing options - ENHANCED FOR HIKING/CYCLING
route
drive-on-left
report-roundabout-issues
add-boundary-nodes-at-admin-boundaries=2
process-exits
process-destination

# Hiking and cycling routing
make-opposite-cycleways
ignore-turn-restrictions
ignore-maxspeeds

# Index options
index
housenumbers

# Address search
location-autofill=is_in,nearest

# Performance
max-jobs
EOF

# Step 6: Build the Garmin map
echo ""
echo "[6/6] Building Garmin map file..."

mkgmap \
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
    echo "   (Backup any existing gmapsupp.img first!)"
    echo "3. Safely eject and restart your watch"
    echo "4. On watch: Settings > Map > Select Map"
    echo ""
else
    echo "ERROR: gmapsupp.img was not created!"
    echo "Checking for individual map files..."
    
    # Try to create gmapsupp.img from individual files
    if ls "$OUTPUT_DIR"/6324*.img 1> /dev/null 2>&1; then
        echo "Found individual map files, combining them..."
        mkgmap \
            --gmapsupp \
            --output-dir="$OUTPUT_DIR" \
            "$OUTPUT_DIR"/6324*.img
        
        if [ -f "$OUTPUT_DIR/gmapsupp.img" ]; then
            echo "Successfully created gmapsupp.img"
        else
            echo "Failed to create combined map file"
            exit 1
        fi
    else
        echo "No map files found!"
        exit 1
    fi
fi

# Optional: Create additional formats
echo "Creating named map file for reference..."
cp "$OUTPUT_DIR/gmapsupp.img" "$OUTPUT_DIR/${MAP_NAME}.img"

echo ""
echo "Files created:"
echo "  - gmapsupp.img (copy this to watch /GARMIN/ folder)"
echo "  - ${MAP_NAME}.img (backup/reference copy)"
echo ""
echo "Build complete! Files available in: $OUTPUT_DIR"
ls -lh "$OUTPUT_DIR"/*.img