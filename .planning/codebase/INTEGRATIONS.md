# External Integrations & Native Plugins

## Native Platform Channels & Plugins
1. **Google ML Kit Document Scanner (`cunning_document_scanner`):**
   - Provides native ML Kit document scanning UI with automatic edge detection and auto-capture on Android.
2. **Image Cropper (`image_cropper`):**
   - Native crop and deskew UI on Android (uCrop) and iOS (TOCropViewController).
3. **PDF Engine & Printing (`pdf`, `pdfrx`, `syncfusion_flutter_pdf`, `printing`):**
   - `pdf`: Pure Dart PDF generation.
   - `syncfusion_flutter_pdf`: Manipulating existing PDFs (merging, splitting, compressing).
   - `pdfrx`: Fast native PDF rendering in Flutter views.
   - `printing`: System print dialog and native PDF sharing pipelines.
4. **File System & Pickers (`path_provider`, `file_picker`, `image_picker`):**
   - Scoped storage access and document picking without requiring invasive device permissions.
5. **System Sharing (`share_plus`):**
   - Direct integration with Android Intent share sheet and iOS UIActivityViewController.

## Cloud Integrations (Planned)
- Remote PDF conversion endpoint for heavy document formats (DOCX/XLSX/PPTX) in Non-Confidential Mode.

