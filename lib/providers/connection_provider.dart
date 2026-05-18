import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:nearby_connections/nearby_connections.dart';

import '../models/service_order.dart';
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

  bool _isHost = false; // Tracks if this device is the Advertiser (Server)

  String _userName = '';
  String get userName => _userName;

  final List<DiscoveredDevice> _discoveredDevices = [];
  List<DiscoveredDevice> get discoveredDevices =>
      List.unmodifiable(_discoveredDevices);

  final Map<String, String> _connectedEndpoints = {};
  Map<String, String> get connectedEndpoints => Map.unmodifiable(_connectedEndpoints);
  int get connectedCount => _connectedEndpoints.length;

  ServiceOrder? _currentOrder;
  ServiceOrder? get currentOrder => _currentOrder;

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
    _isHost = true;
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
    _isHost = false;
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
    for (final id in _connectedEndpoints.keys) {
      _service.disconnectFromEndpoint(id);
    }
    _connectedEndpoints.clear();
    _currentOrder = null;
    _connectionState = NearbyConnectionState.idle;
    notifyListeners();
  }

  // -- Data exchange ---------------------------------------------------------

  void createServiceOrder(String id) {
    if (!_isHost) return;
    _currentOrder = ServiceOrder(
      id: id,
      status: 'Aberto',
      createdBy: _userName,
      createdAt: DateTime.now(),
    );
    notifyListeners();
    _broadcastCurrentOrder();
  }

  void addTag(String blockPoint) {
    if (_currentOrder == null) return;

    final newTag = Tag(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      blockPoint: blockPoint,
      addedBy: _userName,
      addedAt: DateTime.now(),
    );

    _currentOrder!.tags.add(newTag);
    notifyListeners();
    _broadcastCurrentOrder();
  }

  void _broadcastCurrentOrder() {
    if (_currentOrder == null || _connectedEndpoints.isEmpty) return;
    
    final payloadStr = jsonEncode({
      'type': 'sync_order',
      'order': _currentOrder!.toMap(),
    });

    for (final id in _connectedEndpoints.keys) {
      _service.sendTextMessage(id, payloadStr);
    }
  }

  // -- Cleanup ---------------------------------------------------------------

  Future<void> stopAll() async {
    await _service.stopAllEndpoints();
    _connectionState = NearbyConnectionState.idle;
    _discoveredDevices.clear();
    _connectedEndpoints.clear();
    _currentOrder = null;
    _pendingEndpointId = null;
    _pendingConnectionInfo = null;
    notifyListeners();
  }

  // -- Private callbacks -----------------------------------------------------

  void _onConnectionInitiated(String endpointId, ConnectionInfo info) {
    _pendingEndpointId = endpointId;
    _pendingConnectionInfo = info;
    notifyListeners();

    // Auto-accept for POC simplicity
    acceptPendingConnection();
  }

  void _onConnectionResult(String endpointId, Status status) {
    if (status == Status.CONNECTED) {
      final deviceName = _pendingConnectionInfo?.endpointName ?? 'Unknown';
      _connectedEndpoints[endpointId] = deviceName;
      _connectionState = NearbyConnectionState.connected;
      
      // Send current state to newly connected client if we are host
      if (_isHost && _currentOrder != null) {
         final payloadStr = jsonEncode({
          'type': 'sync_order',
          'order': _currentOrder!.toMap(),
        });
        _service.sendTextMessage(endpointId, payloadStr);
      }
    } else {
      if (_connectedEndpoints.isEmpty) {
        _connectionState = NearbyConnectionState.idle;
      }
      _errorMessage = 'Connection ${status == Status.REJECTED ? 'rejected' : 'failed'}';
    }
    notifyListeners();
  }

  void _onDisconnected(String endpointId) {
    if (_connectedEndpoints.containsKey(endpointId)) {
      final name = _connectedEndpoints[endpointId];
      _connectedEndpoints.remove(endpointId);
      
      if (_connectedEndpoints.isEmpty) {
        _connectionState = NearbyConnectionState.idle;
      }
      
      // Could show a snackbar or log that someone disconnected
      debugPrint('$name disconnected');
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
      final jsonStr = utf8.decode(payload.bytes!);

      try {
        final data = jsonDecode(jsonStr);
        final msgType = data['type'];

        if (msgType == 'sync_order') {
          _currentOrder = ServiceOrder.fromMap(data['order']);
          notifyListeners();

          // Rebroadcast to keep everyone else in sync
          if (_isHost) {
            _forwardPayload(endpointId, jsonStr);
          }
        }
      } catch (e) {
        debugPrint('Error parsing payload: $e');
      }
    }
  }

  void _forwardPayload(String senderEndpointId, String payloadStr) {
    for (final id in _connectedEndpoints.keys) {
      if (id != senderEndpointId) {
        _service.sendTextMessage(id, payloadStr);
      }
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
