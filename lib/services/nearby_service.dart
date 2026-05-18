import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';

/// Service ID used to uniquely identify this app for nearby connections.
const String kServiceId = 'com.example.offline_sharing';

/// Strategy used for nearby connections.
const Strategy kStrategy = Strategy.P2P_CLUSTER;

/// Wraps the [Nearby] API and provides a simplified interface for
/// advertising, discovering, connecting, and exchanging data.
class NearbyService {
  final Nearby _nearby = Nearby();

  // ---------------------------------------------------------------------------
  // Permissions
  // ---------------------------------------------------------------------------

  /// Requests all runtime permissions required by the Nearby Connections API.
  /// Returns `true` if all critical permissions were granted.
  Future<bool> requestPermissions() async {
    try {
      // Location
      if (!await Permission.location.isGranted) {
        final status = await Permission.location.request();
        debugPrint('[NearbyService] Location permission: $status');
        if (!status.isGranted) return false;
      }

      // Bluetooth permissions (Android 12+)
      final bluetoothPermissions = [
        Permission.bluetooth,
        Permission.bluetoothAdvertise,
        Permission.bluetoothConnect,
        Permission.bluetoothScan,
      ];

      final btResults = await bluetoothPermissions.request();
      debugPrint('[NearbyService] Bluetooth permissions: $btResults');

      // Nearby Wi-Fi Devices (Android 13+)
      try {
        final wifiResult = await Permission.nearbyWifiDevices.request();
        debugPrint('[NearbyService] Nearby Wi-Fi Devices: $wifiResult');
      } catch (e) {
        debugPrint('[NearbyService] nearbyWifiDevices not available: $e');
      }

      // Storage (for file payloads)
      try {
        final storageResult = await Permission.storage.request();
        debugPrint('[NearbyService] Storage: $storageResult');
      } catch (e) {
        debugPrint('[NearbyService] Storage permission error: $e');
      }

      return true;
    } catch (e) {
      debugPrint('[NearbyService] Permission request error: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Advertising
  // ---------------------------------------------------------------------------

  /// Starts advertising this device so that discoverers can find it.
  Future<bool> startAdvertising({
    required String userName,
    required void Function(String endpointId, ConnectionInfo info)
        onConnectionInitiated,
    required void Function(String endpointId, Status status)
        onConnectionResult,
    required void Function(String endpointId) onDisconnected,
  }) async {
    try {
      return await _nearby.startAdvertising(
        userName,
        kStrategy,
        onConnectionInitiated: onConnectionInitiated,
        onConnectionResult: onConnectionResult,
        onDisconnected: onDisconnected,
        serviceId: kServiceId,
      );
    } catch (e) {
      print('Error starting advertising: $e');
      return false;
    }
  }

  /// Stops advertising.
  Future<void> stopAdvertising() async {
    await _nearby.stopAdvertising();
  }

  // ---------------------------------------------------------------------------
  // Discovery
  // ---------------------------------------------------------------------------

  /// Starts discovering nearby advertisers.
  Future<bool> startDiscovery({
    required String userName,
    required void Function(String endpointId, String userName, String serviceId)
        onEndpointFound,
    required void Function(String? endpointId) onEndpointLost,
  }) async {
    try {
      return await _nearby.startDiscovery(
        userName,
        kStrategy,
        onEndpointFound: onEndpointFound,
        onEndpointLost: onEndpointLost,
        serviceId: kServiceId,
      );
    } catch (e) {
      print('Error starting discovery: $e');
      return false;
    }
  }

  /// Stops discovery.
  Future<void> stopDiscovery() async {
    await _nearby.stopDiscovery();
  }

  // ---------------------------------------------------------------------------
  // Connection management
  // ---------------------------------------------------------------------------

  /// Requests a connection to a discovered endpoint.
  Future<void> requestConnection({
    required String userName,
    required String endpointId,
    required void Function(String endpointId, ConnectionInfo info)
        onConnectionInitiated,
    required void Function(String endpointId, Status status)
        onConnectionResult,
    required void Function(String endpointId) onDisconnected,
  }) async {
    try {
      await _nearby.requestConnection(
        userName,
        endpointId,
        onConnectionInitiated: onConnectionInitiated,
        onConnectionResult: onConnectionResult,
        onDisconnected: onDisconnected,
      );
    } catch (e) {
      print('Error requesting connection: $e');
      rethrow;
    }
  }

  /// Accepts an incoming connection and registers payload callbacks.
  Future<void> acceptConnection({
    required String endpointId,
    required void Function(String endpointId, Payload payload)
        onPayloadReceived,
    required void Function(
            String endpointId, PayloadTransferUpdate transferUpdate)
        onPayloadTransferUpdate,
  }) async {
    try {
      await _nearby.acceptConnection(
        endpointId,
        onPayLoadRecieved: onPayloadReceived,
        onPayloadTransferUpdate: onPayloadTransferUpdate,
      );
    } catch (e) {
      print('Error accepting connection: $e');
      rethrow;
    }
  }

  /// Rejects an incoming connection.
  Future<void> rejectConnection(String endpointId) async {
    try {
      await _nearby.rejectConnection(endpointId);
    } catch (e) {
      print('Error rejecting connection: $e');
    }
  }

  /// Disconnects from an endpoint.
  void disconnectFromEndpoint(String endpointId) {
    _nearby.disconnectFromEndpoint(endpointId);
  }

  /// Stops all endpoints (advertising, discovery, connections).
  Future<void> stopAllEndpoints() async {
    await _nearby.stopAllEndpoints();
  }

  // ---------------------------------------------------------------------------
  // Data transfer
  // ---------------------------------------------------------------------------

  /// Sends a text message as a bytes payload.
  Future<void> sendTextMessage(String endpointId, String text) async {
    await _nearby.sendBytesPayload(
      endpointId,
      Uint8List.fromList(utf8.encode(text)),
    );
  }

  /// Sends a file to the connected endpoint.
  /// Returns the payload ID for tracking transfer progress.
  Future<int?> sendFile(String endpointId, String filePath) async {
    try {
      final payloadId = await _nearby.sendFilePayload(endpointId, filePath);
      return payloadId;
    } catch (e) {
      print('Error sending file: $e');
      return null;
    }
  }
}
