# External asset

The primary distant cathedral landmark is downloaded by `scripts/download_assets.sh`.

- **Asset:** Generic gothic cathedral (GLB, 17 MB)
- **Source:** Innerscene Free Parts Library
- **License:** CC0 1.0 / public domain
- **Use:** Static distant landmark behind the scripted gatehouse
- **Download endpoint:** https://www.innerscene.com/api/library/generic-gothic-cathedral-89717f0f/download
- **Library page:** https://www.innerscene.com/tools/library/3d-parts/generic-gothic-cathedral-89717f0f

The GitHub Actions validation and Android build workflows download this asset before Godot imports the project. Local developers can run `bash scripts/download_assets.sh` before opening the project in Godot.

The model is a background landmark; close-range gameplay geometry and collisions remain authored in the Godot project.
