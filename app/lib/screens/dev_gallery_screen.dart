import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../templates/mock_data.dart';
import '../ui/visualization_panel.dart';

/// Debug-only list of every template rendered with mock data.
class DevGalleryScreen extends StatelessWidget {
  const DevGalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Template gallery')),
      body: ListView.separated(
        itemCount: mockSamples.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final sample = mockSamples[i];
          return ListTile(
            title: Text(sample.visualization.props.title),
            subtitle: Text(sample.name),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/dev/$i'),
          );
        },
      ),
    );
  }
}

/// Previews one mock sample with replay and a reduced-motion toggle.
class DevPreviewScreen extends StatefulWidget {
  const DevPreviewScreen({super.key, required this.index});

  final int index;

  @override
  State<DevPreviewScreen> createState() => _DevPreviewScreenState();
}

class _DevPreviewScreenState extends State<DevPreviewScreen> {
  int _replay = 0;
  bool _reduceMotion = false;

  @override
  Widget build(BuildContext context) {
    final sample = mockSamples[widget.index.clamp(0, mockSamples.length - 1)];
    return Scaffold(
      appBar: AppBar(
        title: Text(sample.name),
        actions: [
          IconButton(
            tooltip: _reduceMotion ? 'Allow motion' : 'Reduce motion',
            icon: Icon(_reduceMotion ? Icons.motion_photos_off_outlined : Icons.motion_photos_on_outlined),
            onPressed: () => setState(() {
              _reduceMotion = !_reduceMotion;
              _replay++;
            }),
          ),
          IconButton(
            tooltip: 'Replay',
            icon: const Icon(Icons.replay_rounded),
            onPressed: () => setState(() => _replay++),
          ),
        ],
      ),
      body: MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: _reduceMotion || MediaQuery.disableAnimationsOf(context)),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [VisualizationPanel(visualization: sample.visualization, replayKey: _replay)],
        ),
      ),
    );
  }
}
