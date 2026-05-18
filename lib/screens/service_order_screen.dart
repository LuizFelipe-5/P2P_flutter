import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/connection_provider.dart';
import '../models/service_order.dart';
import 'home_screen.dart';

class ServiceOrderScreen extends StatefulWidget {
  final bool isHost;

  const ServiceOrderScreen({super.key, required this.isHost});

  @override
  State<ServiceOrderScreen> createState() => _ServiceOrderScreenState();
}

class _ServiceOrderScreenState extends State<ServiceOrderScreen> {
  final _tagController = TextEditingController();

  @override
  void dispose() {
    _tagController.dispose();
    super.dispose();
  }

  void _addTag(ConnectionProvider provider) {
    final text = _tagController.text.trim();
    if (text.isNotEmpty) {
      provider.addTag(text);
      _tagController.clear();
      FocusScope.of(context).unfocus();
    }
  }

  void _createOrder(ConnectionProvider provider) {
    // Generate a random ID for the POC
    final orderId = 'OS-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    provider.createServiceOrder(orderId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: Consumer<ConnectionProvider>(
          builder: (context, provider, _) {
            final order = provider.currentOrder;
            if (order == null) return const Text('Ordem de Serviço');
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'OS: ${order.id}',
                  style: GoogleFonts.inter(
                      fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                ),
                Text(
                  '${provider.connectedCount} dispositivos',
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF8B949E)),
                ),
              ],
            );
          },
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () {
            context.read<ConnectionProvider>().disconnect();
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const HomeScreen()),
              (route) => false,
            );
          },
        ),
      ),
      body: Consumer<ConnectionProvider>(
        builder: (context, provider, _) {
          final order = provider.currentOrder;

          if (order == null) {
            return _buildNoOrder(provider);
          }

          return Column(
            children: [
              _buildOrderHeader(order),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: order.tags.length,
                  itemBuilder: (context, index) {
                    final tag = order.tags[index];
                    return _buildTagItem(tag);
                  },
                ),
              ),
              _buildInput(provider),
            ],
          );
        },
      ),
    );
  }

  Widget _buildNoOrder(ConnectionProvider provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.assignment_rounded, size: 64, color: Color(0xFF30363D)),
          const SizedBox(height: 16),
          Text(
            'Nenhuma Ordem de Serviço\nsincronizada',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 18, color: const Color(0xFF8B949E)),
          ),
          const SizedBox(height: 32),
          if (widget.isHost)
            ElevatedButton.icon(
              onPressed: () => _createOrder(provider),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF238636),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: Text(
                'Criar Nova OS',
                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            )
          else
            Text(
              'Aguardando o líder criar a OS...',
              style: GoogleFonts.inter(color: const Color(0xFFF0883E)),
            ),
        ],
      ),
    );
  }

  Widget _buildOrderHeader(ServiceOrder order) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF161B22),
        border: Border(bottom: BorderSide(color: Color(0xFF30363D))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Criado por: ${order.createdBy}',
                style: GoogleFonts.inter(color: const Color(0xFF8B949E), fontSize: 13),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF3FB950),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Status: ${order.status}',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF1F6FEB).withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF1F6FEB).withOpacity(0.5)),
            ),
            child: Text(
              '${order.tags.length} Etiquetas',
              style: GoogleFonts.inter(color: const Color(0xFF58A6FF), fontSize: 12),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTagItem(Tag tag) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF21262D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bookmark_added_rounded, color: Color(0xFFF0883E), size: 20),
              const SizedBox(width: 8),
              Text(
                'Etiqueta adicionada por ${tag.addedBy}',
                style: GoogleFonts.inter(color: const Color(0xFF8B949E), fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Bloqueio: ${tag.blockPoint}',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInput(ConnectionProvider provider) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Color(0xFF161B22),
        border: Border(top: BorderSide(color: Color(0xFF30363D))),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0D1117),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF30363D)),
                ),
                child: TextField(
                  controller: _tagController,
                  style: GoogleFonts.inter(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Nome do Ponto de Bloqueio',
                    hintStyle: GoogleFonts.inter(color: const Color(0xFF8B949E)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () => _addTag(provider),
              child: Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Color(0xFF238636),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add_rounded, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
