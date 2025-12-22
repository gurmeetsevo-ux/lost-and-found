import 'package:flutter/material.dart';
import '../services/algolia_bulk_upload.dart';

class BulkUploadScreen extends StatefulWidget {
  @override
  _BulkUploadScreenState createState() => _BulkUploadScreenState();
}

class _BulkUploadScreenState extends State<BulkUploadScreen> {
  bool _isUploading = false;
  String _statusMessage = 'Ready to upload';
  int _current = 0;
  int _total = 0;
  Map<String, dynamic>? _uploadResult;
  Map<String, dynamic>? _indexStats;

  @override
  void initState() {
    super.initState();
    _checkIndexStatus();
  }

  Future<void> _checkIndexStatus() async {
    Map<String, dynamic> stats = await AlgoliaBulkUpload.getIndexStats();
    setState(() {
      _indexStats = stats;
    });
  }

  Future<void> _startBulkUpload() async {
    setState(() {
      _isUploading = true;
      _statusMessage = 'Starting upload...';
      _current = 0;
      _total = 0;
      _uploadResult = null;
    });

    try {
      Map<String, dynamic> result = await AlgoliaBulkUpload.uploadWithProgress(
        onProgress: (current, total, status) {
          setState(() {
            _current = current;
            _total = total;
            _statusMessage = status;
          });
        },
      );

      setState(() {
        _uploadResult = result;
      });

      // Refresh index stats
      await _checkIndexStatus();

      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Upload completed! ${result['uploaded']} posts uploaded successfully.',
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: ${result['error']}'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }

    } catch (e) {
      setState(() {
        _uploadResult = {
          'success': false,
          'error': e.toString(),
        };
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bulk Upload to Algolia'),
        backgroundColor: Color(0xFF667eea),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Index Status Card
            if (_indexStats != null) ...[
              Card(
                color: _indexStats!['indexExists'] ? Colors.green[50] : Colors.orange[50],
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _indexStats!['indexExists'] ? Icons.check_circle : Icons.info,
                            color: _indexStats!['indexExists'] ? Colors.green : Colors.orange,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Algolia Index Status',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: _indexStats!['indexExists'] ? Colors.green : Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        _indexStats!['indexExists']
                            ? 'Index exists with ${_indexStats!['totalRecords']} records'
                            : 'Index is empty or not accessible',
                        style: TextStyle(
                          fontSize: 14,
                          color: _indexStats!['indexExists'] ? Colors.green : Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),
            ],

            // Upload Card
            Card(
              elevation: 2,
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Upload Existing Posts to Algolia',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'This will upload all existing Firestore posts to Algolia for search functionality. Run this only once after setting up Algolia.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                        height: 1.4,
                      ),
                    ),
                    SizedBox(height: 20),

                    if (_isUploading) ...[
                      // Progress Section
                      LinearProgressIndicator(
                        value: _total > 0 ? _current / _total : null,
                        backgroundColor: Colors.grey,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF667eea)),
                        minHeight: 6,
                      ),
                      SizedBox(height: 12),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _total > 0 ? '$_current / $_total posts' : 'Preparing...',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF667eea),
                            ),
                          ),
                          if (_total > 0)
                            Text(
                              '${((_current / _total) * 100).toInt()}%',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey,
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: 8),

                      Text(
                        _statusMessage,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ] else ...[
                      // Upload Button
                      ElevatedButton(
                        onPressed: _startBulkUpload,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF667eea),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 2,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.cloud_upload, size: 20),
                            SizedBox(width: 12),
                            Text(
                              'Start Bulk Upload',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            SizedBox(height: 16),

            // Results Card
            if (_uploadResult != null) ...[
              Card(
                color: _uploadResult!['success'] ? Colors.green[15] : Colors.red[15],
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _uploadResult!['success'] ? Icons.check_circle : Icons.error,
                            color: _uploadResult!['success'] ? Colors.green : Colors.red,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Upload Results',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: _uploadResult!['success'] ? Colors.green : Colors.red,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),

                      if (_uploadResult!['success']) ...[
                        Text('✅ Successfully uploaded: ${_uploadResult!['uploaded']} posts'),
                        if (_uploadResult!['errors'] > 0)
                          Text('⚠️ Failed uploads: ${_uploadResult!['errors']} posts'),
                        Text('📊 Total processed: ${_uploadResult!['total']} posts'),
                      ] else ...[
                        Text('❌ Upload failed: ${_uploadResult!['error']}'),
                      ],
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),
            ],

            // Warning Card
            Card(
              color: Colors.orange[15],
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber, color: Colors.orange),
                        SizedBox(width: 8),
                        Text(
                          'Important Notes',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Text(
                      '• Run this only ONCE after setting up Algolia\n'
                          '• This will use your Algolia free tier quota\n'
                          '• Make sure your API keys are correctly configured\n'
                          '• Future posts will sync automatically using manual service\n'
                          '• Keep your Admin API key secure and never expose it',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.orange,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
