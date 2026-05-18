import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:nearby_connections/nearby_connections.dart';

import '../models/message.dart';
import '../services/nearby_service.dart';

/// Possible states of the connection lifecycle.
enum NearbyConnectionState {
  idle,
  advertising,
  discovering,
  connecting,
  connected,
}

/// Represents a discovered device that can be connected to.
class DiscoveredDevice {
  final String endpointId;
  final String userName;

  DiscoveredDevice({required this.endpointId, required this.userName});
}

/// Central state manager for the nearby connection lifecycle.
///
/// Manages advertising, discovery, connection, and data exchange state
/// and notifies listeners (UI) of changes.
class ConnectionProvider extends ChangeNotifier {
  final NearbyService _service = NearbyService();

  // -- State fields ----------------------------------------------------------

  NearbyConnectionState _connectionState = NearbyConnectionState.idle;
  NearbyConnectionState get connectionState => _connectionState;

  String _userName = '';
  String get userName => _userName;

  final List<DiscoveredDevice> _discoveredDevices = [];
  List<DiscoveredDevice> get discoveredDevices =>
      List.unmodifiable(_discoveredDevices);

  String? _connectedEndpointId;
  String? get connectedEndpointId => _connectedEndpointId;

  String _connectedDeviceName = '';
  String get connectedDeviceName => _connectedDeviceName;

  final List<ChatMessage> _messages = [];
  List<ChatMessage> get messages => List.unmodifiable(_messages);

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // Pending connection info — used for accept/reject dialog
  String? _pendingEndpointId;
  String? get pendingEndpointId => _pendingEndpointId;

  ConnectionInfo? _pendingConnectionInfo;
  ConnectionInfo? get pendingConnectionInfo => _pendingConnectionInfo;

  // -- Permissions -----------------------------------------------------------

  Future<bool> requestPermissions() => _service.requestPermissions();

  // -- User name -------------------------------------------------------------

  void setUserName(String name) {
    _userName = name;
    notifyListeners();
  }

  // -- Advertising -----------------------------------------------------------

  Future<bool> startAdvertising() async {
    _clearError();
    _connectionState = NearbyConnectionState.advertising;
    notifyListeners();

    final success = await _service.startAdvertising(
      userName: _userName,
      onConnectionInitiated: _onConnectionInitiated,
      onConnectionResult: _onConnectionResult,
      onDisconnected: _onDisconnected,
    );

    if (!success) {
      _connectionState = NearbyConnectionState.idle;
      _errorMessage = 'Failed to start advertising';
      notifyListeners();
    }

    return success;
  }

  Future<void> stopAdvertising() async {
    await _service.stopAdvertising();
    _connectionState = NearbyConnectionState.idle;
    notifyListeners();
  }

  // -- Discovery -------------------------------------------------------------

  Future<bool> startDiscovery() async {
    _clearError();
    _discoveredDevices.clear();
    _connectionState = NearbyConnectionState.discovering;
    notifyListeners();

    final success = await _service.startDiscovery(
      userName: _userName,
      onEndpointFound: _onEndpointFound,
      onEndpointLost: _onEndpointLost,
    );

    if (!success) {
      _connectionState = NearbyConnectionState.idle;
      _errorMessage = 'Failed to start discovery';
      notifyListeners();
    }

    return success;
  }

  Future<void> stopDiscovery() async {
    await _service.stopDiscovery();
    if (_connectionState == NearbyConnectionState.discovering) {
      _connectionState = NearbyConnectionState.idle;
      notifyListeners();
    }
  }

  // -- Connection ------------------------------------------------------------

  Future<void> requestConnection(String endpointId) async {
    _clearError();
    _connectionState = NearbyConnectionState.connecting;
    notifyListeners();

    try {
      await _service.requestConnection(
        userName: _userName,
        endpointId: endpointId,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
      );
    } catch (e) {
      _connectionState = NearbyConnectionState.discovering;
      _errorMessage = 'Failed to request connection: $e';
      notifyListeners();
    }
  }

  Future<void> acceptPendingConnection() async {
    if (_pendingEndpointId == null) return;

    try {
      await _service.acceptConnection(
        endpointId: _pendingEndpointId!,
        onPayloadReceived: _onPayloadReceived,
        onPayloadTransferUpdate: _onPayloadTransferUpdate,
      );
    } catch (e) {
      _errorMessage = 'Failed to accept connection: $e';
      notifyListeners();
    }

    _pendingEndpointId = null;
    _pendingConnectionInfo = null;
  }

  Future<void> rejectPendingConnection() async {
    if (_pendingEndpointId == null) return;

    await _service.rejectConnection(_pendingEndpointId!);
    _pendingEndpointId = null;
    _pendingConnectionInfo = null;
    _connectionState = NearbyConnectionState.idle;
    notifyListeners();
  }

  void disconnect() {
    if (_connectedEndpointId != null) {
      _service.disconnectFromEndpoint(_connectedEndpointId!);
    }
    _connectedEndpointId = null;
    _connectedDeviceName = '';
    _messages.clear();
    _connectionState = NearbyConnectionState.idle;
    notifyListeners();
  }

  // -- Data exchange ---------------------------------------------------------

  Future<void> sendTextMessage(String text) async {
    if (_connectedEndpointId == null || text.trim().isEmpty) return;

    await _service.sendTextMessage(_connectedEndpointId!, text);

    _messages.add(ChatMessage(
      senderName: _userName,
      content: text,
      timestamp: DateTime.now(),
      isMe: true,
      type: MessageType.text,
    ));
    notifyListeners();
  }

  Future<void> sendFile(String filePath, String fileName) async {
    if (_connectedEndpointId == null) return;

    // Send the file payload
    final payloadId =
        await _service.sendFile(_connectedEndpointId!, filePath);

    if (payloadId != null) {
      // Send filename metadata so the receiver knows what it is
      await _service.sendTextMessage(
        _connectedEndpointId!,
        '__FILE_META__:$payloadId:$fileName',
      );

      _messages.add(ChatMessage(
        senderName: _userName,
        content: '📁 $fileName',
        timestamp: DateTime.now(),
        isMe: true,
        type: MessageType.file,
      ));
      notifyListeners();
    }
  }

  // -- Cleanup ---------------------------------------------------------------

  Future<void> stopAll() async {
    await _service.stopAllEndpoints();
    _connectionState = NearbyConnectionState.idle;
    _discoveredDevices.clear();
    _connectedEndpointId = null;
    _connectedDeviceName = '';
    _messages.clear();
    _pendingEndpointId = null;
    _pendingConnectionInfo = null;
    notifyListeners();
  }

  // -- Private callbacks -----------------------------------------------------

  void _onConnectionInitiated(String endpointId, ConnectionInfo info) {
    _pendingEndpointId = endpointId;
    _pendingConnectionInfo = info;
    _connectedDeviceName = info.endpointName;
    notifyListeners();

    // Auto-accept for POC simplicity
    acceptPendingConnection();
  }

  void _onConnectionResult(String endpointId, Status status) {
    if (status == Status.CONNECTED) {
      _connectedEndpointId = endpointId;
      _connectionState = NearbyConnectionState.connected;
      // Stop advertising/discovery once connected
      _service.stopAdvertising();
      _service.stopDiscovery();
    } else {
      _connectionState = NearbyConnectionState.idle;
      _errorMessage = 'Connection ${status == Status.REJECTED ? 'rejected' : 'failed'}';
    }
    notifyListeners();
  }

  void _onDisconnected(String endpointId) {
    if (_connectedEndpointId == endpointId) {
      _connectedEndpointId = null;
      _connectedDeviceName = '';
      _connectionState = NearbyConnectionState.idle;
      _messages.add(ChatMessage(
        senderName: 'System',
        content: 'Device disconnected',
        timestamp: DateTime.now(),
        isMe: false,
        type: MessageType.text,
      ));
      notifyListeners();
    }
  }

  void _onEndpointFound(
      String endpointId, String userName, String serviceId) {
    // Avoid duplicates
    if (!_discoveredDevices.any((d) => d.endpointId == endpointId)) {
      _discoveredDevices.add(
        DiscoveredDevice(endpointId: endpointId, userName: userName),
      );
      notifyListeners();
    }
  }

  void _onEndpointLost(String? endpointId) {
    _discoveredDevices.removeWhere((d) => d.endpointId == endpointId);
    notifyListeners();
  }

  void _onPayloadReceived(String endpointId, Payload payload) {
    if (payload.type == PayloadType.BYTES && payload.bytes != null) {
      final text = utf8.decode(payload.bytes!);

      // Skip file metadata messages from display
      if (text.startsWith('__FILE_META__:')) return;

      _messages.add(ChatMessage(
        senderName: _connectedDeviceName,
        content: text,
        timestamp: DateTime.now(),
        isMe: false,
        type: MessageType.text,
      ));
      notifyListeners();
    } else if (payload.type == PayloadType.FILE) {
      _messages.add(ChatMessage(
        senderName: _connectedDeviceName,
        content: '📁 File received',
        timestamp: DateTime.now(),
        isMe: false,
        type: MessageType.file,
      ));
      notifyListeners();
    }
  }

  void _onPayloadTransferUpdate(
      String endpointId, PayloadTransferUpdate update) {
    // Could be used to show transfer progress in the future.
    if (update.status == PayloadStatus.SUCCESS) {
      // Transfer complete
    }
  }

  void _clearError() {
    _errorMessage = null;
  }
}
