import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:video_player/video_player.dart';
import '../models/shared_file.dart';
import '../config.dart';

class MediaPreviewDialog extends StatefulWidget {
  final SharedFile file;
  final VoidCallback onDownload;

  const MediaPreviewDialog({
    super.key,
    required this.file,
    required this.onDownload,
  });

  @override
  State<MediaPreviewDialog> createState() => _MediaPreviewDialogState();
}

class _MediaPreviewDialogState extends State<MediaPreviewDialog> {
  String _textContent = '';
  bool _isLoadingText = false;
  String? _textError;

  // Audio player state
  AudioPlayer? _audioPlayer;
  PlayerState _audioState = PlayerState.stopped;
  Duration _audioDuration = Duration.zero;
  Duration _audioPosition = Duration.zero;
  bool _isAudioLoading = false;
  String? _audioError;

  // Video player state
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _isVideoLoading = false;
  String? _videoError;
  bool _showVideoControls = true;
  bool _isVideoMuted = false;

  @override
  void initState() {
    super.initState();
    if (_isTextOrCodeFile()) {
      _loadTextContent();
    } else if (_isAudioFile()) {
      _initAudioPlayer();
    } else if (_isVideoFile()) {
      _initVideoPlayer();
    }
  }

  @override
  void dispose() {
    _audioPlayer?.stop();
    _audioPlayer?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  String _getFileExtension() {
    final name = widget.file.fileName;
    if (!name.contains('.')) return '';
    return name.split('.').last.toLowerCase();
  }

  bool _isVideoFile() {
    final ext = _getFileExtension();
    final mime = widget.file.mimeType.toLowerCase();
    return ['mp4', 'mkv', 'mov', 'avi', 'webm', '3gp', 'flv', 'm4v'].contains(ext) || mime.startsWith('video/');
  }

  bool _isAudioFile() {
    final ext = _getFileExtension();
    final mime = widget.file.mimeType.toLowerCase();
    return ['mp3', 'wav', 'ogg', 'm4a', 'aac', 'flac', 'opus', 'wma'].contains(ext) || mime.startsWith('audio/');
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      final h = d.inHours.toString();
      return '$h:$m:$s';
    }
    return '$m:$s';
  }

  bool _isTextOrCodeFile() {
    final ext = _getFileExtension();
    const textExtensions = [
      'txt', 'json', 'js', 'jsx', 'ts', 'tsx', 'css', 'html', 'py', 'dart',
      'log', 'sql', 'md', 'xml', 'yaml', 'yml', 'env', 'csv', 'sh', 'bat',
      'c', 'cpp', 'h', 'java', 'kt', 'rs', 'go', 'php', 'rb'
    ];
    if (textExtensions.contains(ext)) return true;
    final mime = widget.file.mimeType.toLowerCase();
    return mime.startsWith('text/') || mime.contains('json') || mime.contains('javascript');
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = 0;
    double dBytes = bytes.toDouble();
    while (dBytes >= 1024 && i < suffixes.length - 1) {
      dBytes /= 1024;
      i++;
    }
    return '${dBytes.toStringAsFixed(1)} ${suffixes[i]}';
  }

  String _getStreamUrl() {
    final cleanProxy = AppConfig.proxyUrl.endsWith('/')
        ? AppConfig.proxyUrl.substring(0, AppConfig.proxyUrl.length - 1)
        : AppConfig.proxyUrl;

    if (cleanProxy.isNotEmpty) {
      if (widget.file.id.isNotEmpty) {
        return '$cleanProxy/download-file?file_id=${widget.file.id}&preview=true&inline=true&skip_increment=true';
      }
      final hash = widget.file.uniqueShareHash ?? '';
      if (hash.isNotEmpty) {
        return '$cleanProxy/download-file?hash=$hash&preview=true&inline=true&skip_increment=true';
      }
    }

    final cleanWorker = AppConfig.cfWorkerUrl.endsWith('/')
        ? AppConfig.cfWorkerUrl.substring(0, AppConfig.cfWorkerUrl.length - 1)
        : AppConfig.cfWorkerUrl;

    if (cleanWorker.isNotEmpty) {
      if (widget.file.id.isNotEmpty) {
        return '$cleanWorker?file_id=${widget.file.id}&preview=true&inline=true&skip_increment=true';
      }
      final hash = widget.file.uniqueShareHash ?? '';
      if (hash.isNotEmpty) {
        return '$cleanWorker?hash=$hash&preview=true&inline=true&skip_increment=true';
      }
    }

    final cleanSb = AppConfig.supabaseUrl.endsWith('/')
        ? AppConfig.supabaseUrl.substring(0, AppConfig.supabaseUrl.length - 1)
        : AppConfig.supabaseUrl;

    if (widget.file.id.isNotEmpty) {
      return '$cleanSb/functions/v1/download-file?file_id=${widget.file.id}&preview=true&inline=true&skip_increment=true';
    }

    return 'https://drive.google.com/uc?id=${widget.file.googleDriveFileId}&export=download';
  }

  String _getGoogleDriveViewUrl() {
    return 'https://drive.google.com/file/d/${widget.file.googleDriveFileId}/preview';
  }

  Future<void> _loadTextContent() async {
    setState(() {
      _isLoadingText = true;
      _textError = null;
    });

    try {
      final streamUrl = _getStreamUrl();
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(streamUrl));
      request.followRedirects = true;
      request.maxRedirects = 5;
      final streamedResponse = await client.send(request).timeout(
        const Duration(seconds: 15),
      );
      final response = await http.Response.fromStream(streamedResponse);
      client.close();

      if (response.statusCode >= 200 && response.statusCode < 300) {
        String decoded = '';
        try {
          decoded = utf8.decode(response.bodyBytes);
        } catch (_) {
          decoded = String.fromCharCodes(response.bodyBytes);
        }

        if (decoded.length > 60000) {
          decoded = decoded.substring(0, 60000) + '\n\n...[Content truncated for fast preview]...';
        }

        if (mounted) {
          setState(() {
            _textContent = decoded;
            _isLoadingText = false;
          });
        }
      } else {
        throw 'HTTP ${response.statusCode}';
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _textError = 'Could not load text preview ($e).\nUse "Open in Google Drive" or "Download" to view.';
          _isLoadingText = false;
        });
      }
    }
  }

  Future<void> _initAudioPlayer() async {
    if (_audioPlayer != null) return;
    setState(() {
      _isAudioLoading = true;
      _audioError = null;
    });

    try {
      final streamUrl = _getStreamUrl();
      final player = AudioPlayer();
      _audioPlayer = player;

      player.onPlayerStateChanged.listen((state) {
        if (mounted) setState(() => _audioState = state);
      });

      player.onDurationChanged.listen((dur) {
        if (mounted) setState(() => _audioDuration = dur);
      });

      player.onPositionChanged.listen((pos) {
        if (mounted) setState(() => _audioPosition = pos);
      });

      player.onPlayerComplete.listen((_) {
        if (mounted) {
          setState(() {
            _audioState = PlayerState.completed;
            _audioPosition = Duration.zero;
          });
        }
      });

      await player.setSource(UrlSource(streamUrl));
      if (mounted) {
        setState(() => _isAudioLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAudioLoading = false;
          _audioError = 'Could not load audio in-app ($e)';
        });
      }
    }
  }

  Future<void> _toggleAudioPlay() async {
    if (_audioPlayer == null) {
      await _initAudioPlayer();
      return;
    }
    try {
      if (_audioState == PlayerState.playing) {
        await _audioPlayer!.pause();
      } else {
        if (_audioState == PlayerState.completed) {
          await _audioPlayer!.seek(Duration.zero);
        }
        await _audioPlayer!.resume();
      }
    } catch (e) {
      debugPrint('[AudioPlayer] Toggle play error: $e');
    }
  }

  Future<void> _seekAudioRelative(int seconds) async {
    if (_audioPlayer == null) return;
    final cur = _audioPosition.inSeconds;
    final total = _audioDuration.inSeconds;
    final target = (cur + seconds).clamp(0, total > 0 ? total : 0);
    await _audioPlayer!.seek(Duration(seconds: target));
  }

  Future<void> _initVideoPlayer() async {
    if (_videoController != null) return;
    setState(() {
      _isVideoLoading = true;
      _videoError = null;
    });

    try {
      final streamUrl = _getStreamUrl();
      final controller = VideoPlayerController.networkUrl(Uri.parse(streamUrl));
      _videoController = controller;

      await controller.initialize();
      controller.addListener(() {
        if (mounted) setState(() {});
      });

      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
          _isVideoLoading = false;
        });
        await controller.play();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isVideoLoading = false;
          _videoError = 'In-app playback failed ($e)';
        });
      }
    }
  }

  void _toggleVideoPlay() {
    if (_videoController == null || !_isVideoInitialized) return;
    if (_videoController!.value.isPlaying) {
      _videoController!.pause();
    } else {
      if (_videoController!.value.position >= _videoController!.value.duration) {
        _videoController!.seekTo(Duration.zero);
      }
      _videoController!.play();
    }
    setState(() {});
  }

  void _seekVideoRelative(int seconds) {
    if (_videoController == null || !_isVideoInitialized) return;
    final cur = _videoController!.value.position.inSeconds;
    final total = _videoController!.value.duration.inSeconds;
    final target = (cur + seconds).clamp(0, total);
    _videoController!.seekTo(Duration(seconds: target));
  }

  void _toggleVideoMute() {
    if (_videoController == null) return;
    _isVideoMuted = !_isVideoMuted;
    _videoController!.setVolume(_isVideoMuted ? 0.0 : 1.0);
    setState(() {});
  }

  Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open URL: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final file = widget.file;
    final ext = _getFileExtension();
    final mime = file.mimeType.toLowerCase();

    final isImage = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'svg'].contains(ext) || mime.startsWith('image/');
    final isVideo = ['mp4', 'mkv', 'mov', 'avi', 'webm', '3gp', 'flv'].contains(ext) || mime.startsWith('video/');
    final isAudio = ['mp3', 'wav', 'ogg', 'm4a', 'aac', 'flac', 'opus'].contains(ext) || mime.startsWith('audio/');
    final isPdf = ext == 'pdf' || mime.contains('pdf');
    final isText = _isTextOrCodeFile();
    final isApk = ext == 'apk' || mime.contains('android.package-archive');

    final streamUrl = _getStreamUrl();
    final driveViewUrl = _getGoogleDriveViewUrl();

    final dialogBg = isLight ? Colors.white : const Color(0xFF0F172A);
    final borderColor = isLight ? const Color(0xFFE2E8F0) : Colors.white.withOpacity(0.08);
    final headerBg = isLight ? const Color(0xFFF8FAFC) : const Color(0xFF1E293B).withOpacity(0.6);
    final titleColor = isLight ? const Color(0xFF0F172A) : Colors.white;
    final subColor = isLight ? const Color(0xFF64748B) : Colors.grey.shade400;
    final cardBg = isLight ? const Color(0xFFF8FAFC) : const Color(0xFF0B1329);

    return Dialog(
      backgroundColor: dialogBg,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: borderColor),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 680),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Dialog Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: headerBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(bottom: BorderSide(color: borderColor)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isImage
                          ? Colors.green.withOpacity(0.15)
                          : isVideo
                              ? Colors.purple.withOpacity(0.15)
                              : isAudio
                                  ? Colors.cyan.withOpacity(0.15)
                                  : isPdf
                                      ? Colors.red.withOpacity(0.15)
                                      : isText
                                          ? Colors.amber.withOpacity(0.15)
                                          : const Color(0xFF4F46E5).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isImage
                          ? LucideIcons.image
                          : isVideo
                              ? LucideIcons.video
                              : isAudio
                                  ? LucideIcons.music
                                  : isPdf
                                      ? LucideIcons.fileText
                                      : isText
                                          ? LucideIcons.code
                                          : LucideIcons.file,
                      color: isImage
                          ? Colors.green
                          : isVideo
                              ? Colors.purpleAccent
                              : isAudio
                                  ? Colors.cyan
                                  : isPdf
                                      ? Colors.redAccent
                                      : isText
                                          ? Colors.amber.shade600
                                          : const Color(0xFF4F46E5),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          file.fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: titleColor,
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${_formatFileSize(file.fileSize)} • ${ext.toUpperCase()}',
                          style: TextStyle(color: subColor, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(LucideIcons.x, color: subColor, size: 18),
                  ),
                ],
              ),
            ),

            // Preview Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // --- 1. IMAGE PREVIEW ---
                    if (isImage) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          constraints: const BoxConstraints(maxHeight: 320),
                          color: isLight ? const Color(0xFFF1F5F9) : const Color(0xFF030712),
                          child: InteractiveViewer(
                            panEnabled: true,
                            minScale: 0.8,
                            maxScale: 4.0,
                            child: Image.network(
                              streamUrl,
                              fit: BoxFit.contain,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(32.0),
                                    child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  padding: const EdgeInsets.all(24),
                                  alignment: Alignment.center,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(LucideIcons.imageOff, size: 40, color: Colors.grey),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Image preview could not load directly.',
                                        style: TextStyle(color: subColor, fontSize: 12),
                                      ),
                                      const SizedBox(height: 10),
                                      OutlinedButton.icon(
                                        onPressed: () => _launchUrl(driveViewUrl),
                                        icon: const Icon(LucideIcons.externalLink, size: 13),
                                        label: const Text('View in Google Drive', style: TextStyle(fontSize: 11)),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: const Color(0xFF4F46E5),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Pinch to zoom & drag to pan', style: TextStyle(color: subColor, fontSize: 11)),
                    ]

                    // --- 2. VIDEO PREVIEW (IN-APP PLAYER) ---
                    else if (isVideo) ...[
                      if (_isVideoLoading) ...[
                        Container(
                          height: 240,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isLight ? const Color(0xFFF1F5F9) : const Color(0xFF030712),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: borderColor),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const CircularProgressIndicator(color: Color(0xFF7C3AED)),
                              const SizedBox(height: 14),
                              Text(
                                'Connecting video stream...',
                                style: TextStyle(color: subColor, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ] else if (_videoError != null || _videoController == null || !_isVideoInitialized) ...[
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: borderColor),
                          ),
                          child: Column(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: Colors.purple.withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(LucideIcons.alertCircle, color: Colors.purpleAccent, size: 30),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'In-App Video Stream Notice',
                                style: TextStyle(color: titleColor, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _videoError ?? 'Stream could not be decoded by device hardware. Watch directly via external player.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: subColor, fontSize: 11.5),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: () => _launchUrl(streamUrl),
                                    icon: const Icon(LucideIcons.externalLink, size: 14),
                                    label: const Text('Play via Chrome / VLC', style: TextStyle(fontSize: 12)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF7C3AED),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton.icon(
                                    onPressed: () => _launchUrl(driveViewUrl),
                                    icon: const Icon(LucideIcons.play, size: 14),
                                    label: const Text('Google Drive', style: TextStyle(fontSize: 12)),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF7C3AED),
                                      side: const BorderSide(color: Color(0xFF7C3AED)),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            color: Colors.black,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _showVideoControls = !_showVideoControls;
                                    });
                                  },
                                  child: AspectRatio(
                                    aspectRatio: _videoController!.value.aspectRatio > 0
                                        ? _videoController!.value.aspectRatio
                                        : 16 / 9,
                                    child: VideoPlayer(_videoController!),
                                  ),
                                ),
                                // Center Play/Pause button
                                if (_showVideoControls || !_videoController!.value.isPlaying)
                                  GestureDetector(
                                    onTap: _toggleVideoPlay,
                                    child: Container(
                                      width: 52,
                                      height: 52,
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.55),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                                      ),
                                      child: Icon(
                                        _videoController!.value.isPlaying ? LucideIcons.pause : LucideIcons.play,
                                        color: Colors.white,
                                        size: 26,
                                      ),
                                    ),
                                  ),
                                // Bottom overlay bar
                                if (_showVideoControls || !_videoController!.value.isPlaying)
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.bottomCenter,
                                          end: Alignment.topCenter,
                                          colors: [
                                            Colors.black.withOpacity(0.85),
                                            Colors.transparent,
                                          ],
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          VideoProgressIndicator(
                                            _videoController!,
                                            allowScrubbing: true,
                                            padding: const EdgeInsets.symmetric(vertical: 4),
                                            colors: const VideoProgressColors(
                                              playedColor: Color(0xFF7C3AED),
                                              bufferedColor: Colors.white24,
                                              backgroundColor: Colors.white12,
                                            ),
                                          ),
                                          Row(
                                            children: [
                                              GestureDetector(
                                                onTap: _toggleVideoPlay,
                                                child: Icon(
                                                  _videoController!.value.isPlaying ? LucideIcons.pause : LucideIcons.play,
                                                  color: Colors.white,
                                                  size: 16,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              GestureDetector(
                                                onTap: () => _seekVideoRelative(-10),
                                                child: const Icon(LucideIcons.rotateCcw, color: Colors.white70, size: 14),
                                              ),
                                              const SizedBox(width: 8),
                                              GestureDetector(
                                                onTap: () => _seekVideoRelative(10),
                                                child: const Icon(LucideIcons.rotateCw, color: Colors.white70, size: 14),
                                              ),
                                              const SizedBox(width: 10),
                                              Text(
                                                '${_formatDuration(_videoController!.value.position)} / ${_formatDuration(_videoController!.value.duration)}',
                                                style: const TextStyle(color: Colors.white70, fontSize: 11),
                                              ),
                                              const Spacer(),
                                              GestureDetector(
                                                onTap: _toggleVideoMute,
                                                child: Icon(
                                                  _isVideoMuted ? LucideIcons.volumeX : LucideIcons.volume2,
                                                  color: Colors.white70,
                                                  size: 16,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              onPressed: () => _launchUrl(streamUrl),
                              icon: const Icon(LucideIcons.externalLink, size: 12),
                              label: const Text('Open External (VLC/Chrome)', style: TextStyle(fontSize: 11)),
                              style: TextButton.styleFrom(foregroundColor: const Color(0xFF7C3AED)),
                            ),
                          ],
                        ),
                      ],
                    ]

                    // --- 3. AUDIO PREVIEW (IN-APP PLAYER) ---
                    else if (isAudio) ...[
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          children: [
                            // Album Art / Disc Icon
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF0891B2).withOpacity(0.15),
                                border: Border.all(
                                  color: _audioState == PlayerState.playing
                                      ? const Color(0xFF06B6D4)
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                LucideIcons.music,
                                color: Color(0xFF06B6D4),
                                size: 34,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              file.fileName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: titleColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _isAudioLoading
                                  ? 'Loading audio stream...'
                                  : _audioError != null
                                      ? _audioError!
                                      : 'In-App Lossless Audio Stream',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _audioError != null ? Colors.redAccent : subColor,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Progress Slider
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                                trackHeight: 3.5,
                                activeTrackColor: const Color(0xFF06B6D4),
                                inactiveTrackColor: isLight ? Colors.grey.shade300 : Colors.white12,
                                thumbColor: const Color(0xFF06B6D4),
                              ),
                              child: Slider(
                                min: 0.0,
                                max: _audioDuration.inMilliseconds > 0
                                    ? _audioDuration.inMilliseconds.toDouble()
                                    : 1.0,
                                value: _audioPosition.inMilliseconds
                                    .clamp(
                                      0,
                                      _audioDuration.inMilliseconds > 0
                                          ? _audioDuration.inMilliseconds
                                          : 1,
                                    )
                                    .toDouble(),
                                onChanged: (val) {
                                  _audioPlayer?.seek(Duration(milliseconds: val.toInt()));
                                },
                              ),
                            ),

                            // Duration Labels
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatDuration(_audioPosition),
                                    style: TextStyle(color: subColor, fontSize: 11),
                                  ),
                                  Text(
                                    _formatDuration(_audioDuration),
                                    style: TextStyle(color: subColor, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Controls Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  onPressed: () => _seekAudioRelative(-10),
                                  icon: const Icon(LucideIcons.rotateCcw, size: 20),
                                  color: subColor,
                                  tooltip: 'Rewind 10s',
                                ),
                                const SizedBox(width: 14),
                                GestureDetector(
                                  onTap: _isAudioLoading ? null : _toggleAudioPlay,
                                  child: Container(
                                    width: 52,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF06B6D4), Color(0xFF3B82F6)],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF06B6D4).withOpacity(0.35),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: _isAudioLoading
                                        ? const Center(
                                            child: SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.2,
                                                color: Colors.white,
                                              ),
                                            ),
                                          )
                                        : Icon(
                                            _audioState == PlayerState.playing
                                                ? LucideIcons.pause
                                                : LucideIcons.play,
                                            color: Colors.white,
                                            size: 24,
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                IconButton(
                                  onPressed: () => _seekAudioRelative(10),
                                  icon: const Icon(LucideIcons.rotateCw, size: 20),
                                  color: subColor,
                                  tooltip: 'Forward 10s',
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                TextButton.icon(
                                  onPressed: () => _launchUrl(streamUrl),
                                  icon: const Icon(LucideIcons.externalLink, size: 12),
                                  label: const Text('Open External', style: TextStyle(fontSize: 11)),
                                  style: TextButton.styleFrom(foregroundColor: const Color(0xFF0891B2)),
                                ),
                                const SizedBox(width: 8),
                                TextButton.icon(
                                  onPressed: () => _launchUrl(driveViewUrl),
                                  icon: const Icon(LucideIcons.play, size: 12),
                                  label: const Text('Drive Player', style: TextStyle(fontSize: 11)),
                                  style: TextButton.styleFrom(foregroundColor: const Color(0xFF0891B2)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ]

                    // --- 4. TEXT / CODE PREVIEW ---
                    else if (isText) ...[
                      if (_isLoadingText) ...[
                        Container(
                          padding: const EdgeInsets.all(36),
                          alignment: Alignment.center,
                          child: Column(
                            children: [
                              const CircularProgressIndicator(color: Color(0xFF4F46E5)),
                              const SizedBox(height: 12),
                              Text('Loading text content...', style: TextStyle(color: subColor, fontSize: 12)),
                            ],
                          ),
                        ),
                      ] else if (_textError != null) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: borderColor),
                          ),
                          child: Column(
                            children: [
                              const Icon(LucideIcons.alertCircle, color: Colors.amber, size: 32),
                              const SizedBox(height: 8),
                              Text(_textError!, textAlign: TextAlign.center, style: TextStyle(color: subColor, fontSize: 12)),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: () => _launchUrl(driveViewUrl),
                                icon: const Icon(LucideIcons.externalLink, size: 13),
                                label: const Text('Open in Google Drive', style: TextStyle(fontSize: 11)),
                                style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF4F46E5)),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(maxHeight: 300),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isLight ? const Color(0xFFF1F5F9) : const Color(0xFF030712),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: borderColor),
                          ),
                          child: SingleChildScrollView(
                            child: SelectableText(
                              _textContent,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11.5,
                                color: isLight ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                                height: 1.4,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: _textContent));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Text copied to clipboard!'), behavior: SnackBarBehavior.floating),
                                );
                              },
                              icon: const Icon(LucideIcons.copy, size: 13),
                              label: const Text('Copy Text', style: TextStyle(fontSize: 11)),
                              style: TextButton.styleFrom(foregroundColor: const Color(0xFF4F46E5)),
                            ),
                          ],
                        ),
                      ],
                    ]

                    // --- 5. PDF & DOCUMENTS ---
                    else if (isPdf) ...[
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(LucideIcons.fileText, color: Colors.redAccent, size: 36),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'PDF Document',
                              style: TextStyle(color: titleColor, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'View PDF document directly in Google Drive or your default PDF viewer.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: subColor, fontSize: 11.5),
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () => _launchUrl(driveViewUrl),
                                  icon: const Icon(LucideIcons.externalLink, size: 14),
                                  label: const Text('Google Drive Preview', style: TextStyle(fontSize: 12)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFDC2626),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => _launchUrl('https://docs.google.com/viewer?url=${Uri.encodeComponent(streamUrl)}'),
                                  icon: const Icon(LucideIcons.fileText, size: 14),
                                  label: const Text('Docs Viewer', style: TextStyle(fontSize: 12)),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFFDC2626),
                                    side: const BorderSide(color: Color(0xFFDC2626)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => _launchUrl(streamUrl),
                                  icon: const Icon(LucideIcons.globe, size: 14),
                                  label: const Text('Direct Stream', style: TextStyle(fontSize: 12)),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFFDC2626),
                                    side: const BorderSide(color: Color(0xFFDC2626)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ]

                    // --- 6. OTHER FILES (APK, ZIP, ETC.) ---
                    else ...[
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: const Color(0xFF4F46E5).withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isApk ? LucideIcons.smartphone : LucideIcons.file,
                                color: const Color(0xFF4F46E5),
                                size: 36,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              isApk ? 'Android Package (APK)' : 'Binary File (${ext.toUpperCase()})',
                              style: TextStyle(color: titleColor, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Download file to install or open with compatible application.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: subColor, fontSize: 11.5),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () => _launchUrl(driveViewUrl),
                              icon: const Icon(LucideIcons.externalLink, size: 14),
                              label: const Text('Open in Google Drive', style: TextStyle(fontSize: 12)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4F46E5),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Universal Action Row: Download & Drive Links
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              widget.onDownload();
                            },
                            icon: const Icon(LucideIcons.download, size: 14),
                            label: const Text('Download File', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4F46E5),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () => _launchUrl(driveViewUrl),
                          icon: const Icon(LucideIcons.externalLink, size: 14),
                          label: const Text('Drive', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF4F46E5),
                            side: const BorderSide(color: Color(0xFF4F46E5)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
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
