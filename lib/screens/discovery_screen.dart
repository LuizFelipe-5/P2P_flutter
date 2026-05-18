import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/connection_provider.dart';
import 'chat_screen.dart';

class DiscoveryScreen extends StatefulWidget {
  final bool isAdvertiser;
  const DiscoveryScreen({super.key, required this.isAdvertiser});

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen>
    with TickerProviderStateMixin {
  late AnimationController _radarController;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    if (_started) return;
    _started = true;
    final provider = context.read<ConnectionProvider>();
    if (widget.isAdvertiser) {
      await provider.startAdvertising();
    } else {
      await provider.startDiscovery();
    }
  }

  @override
  void dispose() {
    _radarController.dispose();
    super.dispose();
  }

  void _navigateToChat() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const ChatScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectionProvider>(
      builder: (context, provider, _) {
        if (provider.connectionState == NearbyConnectionState.connected) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _navigateToChat());
        }
        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0D1117), Color(0xFF161B22), Color(0xFF0D1117)],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  _buildAppBar(provider),
                  const SizedBox(height: 24),
                  _buildRadar(),
                  const SizedBox(height: 32),
                  _buildStatus(provider),
                  const SizedBox(height: 24),
                  if (provider.errorMessage != null)
                    _errorBanner(provider.errorMessage!),
                  if (!widget.isAdvertiser)
                    Expanded(child: _deviceList(provider))
                  else
                    const Spacer(),
                  _bottomAction(provider),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppBar(ConnectionProvider p) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(children: [
        IconButton(
          onPressed: () { p.stopAll(); Navigator.pop(context); },
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Color(0xFF8B949E)),
        ),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.isAdvertiser ? 'Advertising' : 'Discovering',
              style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white)),
          Text('as "${p.userName}"',
              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF8B949E))),
        ]),
      ]),
    );
  }

  Widget _buildRadar() {
    final color = widget.isAdvertiser ? const Color(0xFF58A6FF) : const Color(0xFF3FB950);
    return SizedBox(
      width: 200, height: 200,
      child: Stack(alignment: Alignment.center, children: [
        ...List.generate(3, (i) => AnimatedBuilder(
          animation: _radarController,
          builder: (_, __) {
            final p = ((_radarController.value + i / 3) % 1.0);
            return Container(
              width: 80 + p * 120, height: 80 + p * 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color.withOpacity(0.4 * (1 - p)), width: 2),
              ),
            );
          },
        )),
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: [color, color.withOpacity(0.7)]),
            boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 20, spreadRadius: 2)],
          ),
          child: Icon(widget.isAdvertiser ? Icons.cell_tower_rounded : Icons.radar_rounded,
              color: Colors.white, size: 32),
        ),
      ]),
    );
  }

  Widget _buildStatus(ConnectionProvider p) {
    String text; Color color;
    switch (p.connectionState) {
      case NearbyConnectionState.advertising:
        text = 'Waiting for devices...'; color = const Color(0xFF58A6FF);
      case NearbyConnectionState.discovering:
        text = 'Scanning for nearby devices...'; color = const Color(0xFF3FB950);
      case NearbyConnectionState.connecting:
        text = 'Connecting...'; color = const Color(0xFFF0883E);
      case NearbyConnectionState.connected:
        text = 'Connected to ${p.connectedDeviceName}!'; color = const Color(0xFF3FB950);
      default:
        text = 'Ready'; color = const Color(0xFF8B949E);
    }
    return Text(text, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500, color: color));
  }

  Widget _errorBanner(String error) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFF5C1D1D).withOpacity(0.3),
        border: Border.all(color: const Color(0xFFE53935).withOpacity(0.4)),
      ),
      child: Row(children: [
        const Icon(Icons.error_outline_rounded, color: Color(0xFFE53935), size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(error, style: GoogleFonts.inter(color: const Color(0xFFE53935), fontSize: 13))),
      ]),
    );
  }

  Widget _deviceList(ConnectionProvider p) {
    if (p.discoveredDevices.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.devices_rounded, size: 48, color: Color(0xFF30363D)),
        const SizedBox(height: 12),
        Text('No devices found yet', style: GoogleFonts.inter(fontSize: 15, color: const Color(0xFF484F58))),
      ]));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: p.discoveredDevices.length,
      itemBuilder: (context, i) {
        final d = p.discoveredDevices[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: const Color(0xFF21262D),
            border: Border.all(color: const Color(0xFF30363D)),
          ),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF238636).withOpacity(0.15)),
              child: const Icon(Icons.smartphone_rounded, color: Color(0xFF3FB950), size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(d.userName, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
              Text(d.endpointId, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF484F58))),
            ])),
            p.connectionState == NearbyConnectionState.connecting
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF3FB950)))
                : ElevatedButton(
                    onPressed: () => p.requestConnection(d.endpointId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF238636), foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0,
                    ),
                    child: Text('Connect', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
          ]),
        );
      },
    );
  }

  Widget _bottomAction(ConnectionProvider p) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () { p.stopAll(); Navigator.pop(context); },
          icon: const Icon(Icons.close_rounded),
          label: Text('Cancel', style: GoogleFonts.inter()),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF8B949E),
            side: const BorderSide(color: Color(0xFF30363D)),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }
}
