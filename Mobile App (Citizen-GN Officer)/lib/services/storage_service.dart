import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _userId => _auth.currentUser?.uid ?? 'anonymous';

  /// Document upload — progress tracking සහිතව
  /// Returns download URL after successful upload
  Future<String> uploadDocument({
    required File file,
    required String applicationId,
    required String documentType, // e.g. 'nic', 'birth_certificate'
    String? ownerUserId,
    void Function(double progress)? onProgress,
  }) async {
    final ext = file.path.split('.').last.toLowerCase();

    // Compress image if applicable
    File fileToUpload = file;
    if (ext == 'jpg' || ext == 'jpeg' || ext == 'png') {
      fileToUpload = await _compressImage(file, ext) ?? file;
    }

    final ownerId = ownerUserId != null && ownerUserId.trim().isNotEmpty
        ? ownerUserId.trim()
        : _userId;
    final path = 'applications/$ownerId/$applicationId/$documentType.$ext';
    final ref = _storage.ref().child(path);

    final metadata = SettableMetadata(
      contentType: _getContentType(ext),
      customMetadata: {
        'uploadedBy': _userId,
        'ownerUserId': ownerId,
        'applicationId': applicationId,
        'documentType': documentType,
        'uploadedAt': DateTime.now().toIso8601String(),
      },
    );

    final task = ref.putFile(fileToUpload, metadata);

    // Progress tracking
    if (onProgress != null) {
      task.snapshotEvents.listen((snapshot) {
        if (snapshot.totalBytes > 0) {
          final progress = snapshot.bytesTransferred / snapshot.totalBytes;
          onProgress(progress);
        }
      });
    }

    final snapshot = await task;
    final downloadUrl = await snapshot.ref.getDownloadURL();
    return downloadUrl;
  }

  /// Upload කරපු file delete කරනවා (URL by)
  Future<void> deleteDocument(String downloadUrl) async {
    try {
      final ref = _storage.refFromURL(downloadUrl);
      await ref.delete();
    } catch (_) {
      // File not found — silently ignore
    }
  }

  /// Profile photo upload with progress tracking
  Future<String> uploadProfilePhoto({
    required File file,
    required String userId,
    void Function(double progress)? onProgress,
  }) async {
    final authUser = _auth.currentUser;
    if (authUser == null) {
      throw FirebaseException(
        plugin: 'firebase_storage',
        message: 'User must be signed in to upload profile photos.',
      );
    }
    if (authUser.uid != userId) {
      throw FirebaseException(
        plugin: 'firebase_storage',
        message: 'Signed-in user does not match target profile.',
      );
    }

    final ext = file.path.split('.').last.toLowerCase();

    File fileToUpload = file;
    if (ext == 'jpg' || ext == 'jpeg' || ext == 'png') {
      fileToUpload = await _compressImage(file, ext) ?? file;
    }

    final fileName = 'profile_${DateTime.now().millisecondsSinceEpoch}.$ext';
    final path = 'profile_photos/$userId/$fileName';
    final ref = _storage.ref().child(path);

    final metadata = SettableMetadata(
      contentType: _getContentType(ext),
      customMetadata: {
        'uploadedBy': _userId,
        'targetUserId': userId,
        'uploadedAt': DateTime.now().toIso8601String(),
      },
    );

    final task = ref.putFile(fileToUpload, metadata);

    if (onProgress != null) {
      task.snapshotEvents.listen((snapshot) {
        if (snapshot.totalBytes > 0) {
          final progress = snapshot.bytesTransferred / snapshot.totalBytes;
          onProgress(progress);
        }
      });
    }

    final snapshot = await task;
    return snapshot.ref.getDownloadURL();
  }

  /// File extension to MIME type
  String _getContentType(String ext) {
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'pdf':
        return 'application/pdf';
      default:
        return 'application/octet-stream';
    }
  }

  /// Optional: Compress images using flutter_image_compress
  Future<File?> _compressImage(File file, String ext) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final targetPath =
          '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}_compressed.$ext';

      final format = (ext == 'png') ? CompressFormat.png : CompressFormat.jpeg;

      final xFile = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 70,
        format: format,
      );

      if (xFile != null) {
        return File(xFile.path);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}

final storageService = StorageService();
