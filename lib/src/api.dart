import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import 'actions.dart';
import 'event.dart';

typedef SetupDefaultPhoneAccountShowUserPromptCallback = Future<bool> Function();

bool get isIOS => Platform.isIOS;
bool get isAndroid => Platform.isAndroid;

bool get supportConnectionService => !isIOS && int.parse(Platform.version) >= 23;

class FlutterCallkeep extends EventManager {
  factory FlutterCallkeep() {
    return _instance;
  }
  FlutterCallkeep._internal() {
    _event.setMethodCallHandler(eventListener);
  }
  static final FlutterCallkeep _instance = FlutterCallkeep._internal();
  static const MethodChannel _channel = MethodChannel('FlutterCallKeep.Method');
  static const MethodChannel _event = MethodChannel('FlutterCallKeep.Event');

  Future<void> setup(Map<String, dynamic> options) async {
    if (isAndroid) {
      await _setupAndroid(options['android']);
    } else if (isIOS) {
      await _setupIOS(options['ios']);
    }
  }

  Future<void> registerPhoneAccount() async {
    if (isIOS) {
      return;
    }
    return _channel.invokeMethod<void>('registerPhoneAccount', <String, dynamic>{});
  }

  Future<void> registerAndroidEvents() async {
    if (isIOS) {
      return;
    }
    return _channel.invokeMethod<void>('registerEvents', <String, dynamic>{});
  }

  Future<bool?> _checkDefaultPhoneAccount() async {
    return await _channel.invokeMethod<bool>('checkDefaultPhoneAccount', <String, dynamic>{});
  }

  Future<bool> setupDefaultPhoneAccount(SetupDefaultPhoneAccountShowUserPromptCallback showUserPrompt) =>
      _setupDefaultPhoneAccount(showUserPrompt);

  Future<bool> _setupDefaultPhoneAccount(SetupDefaultPhoneAccountShowUserPromptCallback showUserPrompt) async {
    if (isIOS) {
      return true;
    }

    final hasDefault = await _checkDefaultPhoneAccount() ?? true;
    var shouldOpenAccounts = false;
    if (hasDefault) {
      shouldOpenAccounts = await showUserPrompt();
    }

    if (shouldOpenAccounts) {
      await _openPhoneAccounts();
      return true;
    }

    return false;
  }

  Future<void> displayIncomingCall(
    String uuid,
    String handle, {
    String callerName = '',
    String handleType = 'number',
    bool hasVideo = false,
    Map<String, dynamic> additionalData = const {},
  }) async {
    await _channel.invokeMethod<void>('displayIncomingCall', <String, dynamic>{
      'uuid': uuid,
      'handle': handle,
      'handleType': handleType,
      'hasVideo': hasVideo,
      'callerName': callerName,
      'additionalData': additionalData
    });
  }

  Future<void> answerIncomingCall(String uuid) async {
    await _channel.invokeMethod<void>(
      'answerIncomingCall',
      <String, dynamic>{'uuid': uuid},
    );
  }

  Future<void> startCall(
    String uuid,
    String handle,
    String callerName, {
    String handleType = 'number',
    bool hasVideo = false,
    Map<String, dynamic> additionalData = const {},
  }) async {
    await _channel.invokeMethod<void>('startCall', <String, dynamic>{
      'uuid': uuid,
      'handle': handle,
      'callerName': callerName,
      'handleType': handleType,
      'hasVideo': hasVideo,
      'additionalData': additionalData
    });
  }

  Future<void> reportConnectingOutgoingCallWithUUID(String uuid) async {
    //only available on iOS
    if (isIOS) {
      await _channel.invokeMethod<void>('reportConnectingOutgoingCallWithUUID', <String, dynamic>{'uuid': uuid});
    }
  }

  Future<void> reportConnectedOutgoingCallWithUUID(String uuid) async {
    //only available on iOS
    if (isIOS) {
      await _channel.invokeMethod<void>('reportConnectedOutgoingCallWithUUID', <String, dynamic>{'uuid': uuid});
    }
  }

  Future<void> reportStartedCallWithUUID(String uuid) async {
    if (!isIOS) {
      await _channel.invokeMethod<void>('reportStartedCallWithUUID', <String, dynamic>{'uuid': uuid});
    }
  }

  Future<void> reportEndCallWithUUID(
    String uuid,
    int reason, {
    bool notify = true,
  }) async {
    return await _channel.invokeMethod<void>(
      'reportEndCallWithUUID',
      <String, dynamic>{
        'uuid': uuid,
        'reason': reason,
        'notify': notify,
      },
    );
  }

  /*
   * Android explicitly states we reject a call
   * On iOS we just notify of an endCall
   */
  Future<void> rejectCall(String uuid) async {
    if (!isIOS) {
      await _channel.invokeMethod<void>('rejectCall', <String, dynamic>{'uuid': uuid});
    } else {
      await _channel.invokeMethod<void>('endCall', <String, dynamic>{'uuid': uuid});
    }
  }

  Future<bool> isCallActive(String uuid) async {
    var resp = await _channel.invokeMethod<bool>('isCallActive', <String, dynamic>{'uuid': uuid});
    if (resp != null) {
      return resp;
    }
    return false;
  }

  Future<List<String>> activeCalls() async {
    var resp = await _channel.invokeMethod<List<Object>?>('activeCalls');
    if (resp != null) {
      var uuids = <String>[];
      resp.forEach((element) {
        if (element is String) {
          uuids.add(element);
        }
      });
      return uuids;
    }
    return [];
  }

  Future<void> endCall(String uuid) async =>
      await _channel.invokeMethod<void>('endCall', <String, dynamic>{'uuid': uuid});

  Future<void> endAllCalls() async => await _channel.invokeMethod<void>('endAllCalls');

  FutureOr<bool> hasPhoneAccount() async {
    if (isIOS) {
      return true;
    }
    var resp = await _channel.invokeMethod<bool>('hasPhoneAccount');
    return resp ?? false;
  }

  Future<bool> hasOutgoingCall() async {
    if (isIOS) {
      return true;
    }
    var resp = await _channel.invokeMethod<bool>('hasOutgoingCall');
    return resp ?? false;
  }

  Future<void> setMutedCall(String uuid, bool shouldMute) async =>
      await _channel.invokeMethod<void>('setMutedCall', <String, dynamic>{'uuid': uuid, 'muted': shouldMute});

  Future<void> sendDTMF(String uuid, String key) async =>
      await _channel.invokeMethod<void>('sendDTMF', <String, dynamic>{'uuid': uuid, 'key': key});

  Future<void> checkIfBusy() async => isIOS
      ? await _channel.invokeMethod<void>('checkIfBusy', <String, dynamic>{})
      : throw Exception('CallKeep.checkIfBusy was called from unsupported OS');

  Future<void> checkSpeaker() async => isIOS
      ? await _channel.invokeMethod<void>('checkSpeaker', <String, dynamic>{})
      : throw Exception('CallKeep.checkSpeaker was called from unsupported OS');

  Future<void> setAvailable({bool available = true}) async {
    if (isIOS) {
      return;
    }
    // Tell android that we are able to make outgoing calls
    await _channel.invokeMethod<void>('setAvailable', <String, dynamic>{'available': available});
  }

  Future<void> setCurrentCallActive(String callUUID) async {
    if (isIOS) {
      return;
    }

    await _channel.invokeMethod<void>('setCurrentCallActive', <String, dynamic>{'uuid': callUUID});
  }

  Future<void> updateDisplay(
    String uuid, {
    required String callerName,
    required String handle,
  }) async =>
      await _channel.invokeMethod<void>(
          'updateDisplay', <String, dynamic>{'uuid': uuid, 'callerName': callerName, 'handle': handle});

  Future<void> setOnHold(String uuid, bool shouldHold) async =>
      await _channel.invokeMethod<void>('setOnHold', <String, dynamic>{'uuid': uuid, 'hold': shouldHold});

  Future<void> setReachable({bool reachable = true}) async {
    if (isIOS) {
      return;
    }
    await _channel.invokeMethod<void>('setReachable', <String, dynamic>{
      'reachable': reachable,
    });
  }

  // @deprecated
  Future<void> reportUpdatedCall(
    String uuid,
    String callerName,
  ) async {
    print('CallKeep.reportUpdatedCall is deprecated, use CallKeep.updateDisplay instead');

    return isIOS
        ? await _channel.invokeMethod<void>('reportUpdatedCall', <String, dynamic>{
            'uuid': uuid,
            'callerName': callerName,
          })
        : throw Exception('CallKeep.reportUpdatedCall was called from unsupported OS');
  }

  Future<bool> backToForeground() async {
    if (isIOS) {
      return false;
    }
    var resp = await _channel.invokeMethod<bool>('backToForeground', <String, dynamic>{});
    if (resp != null) {
      return resp;
    }
    return false;
  }

  Future<void> _setupIOS(Map<String, dynamic> options) async {
    if (options['appName'] == null) {
      throw Exception('CallKeep.setup: option "appName" is required');
    }
    if (options['appName'] is String == false) {
      throw Exception('CallKeep.setup: option "appName" should be of type "string"');
    }
    return await _channel.invokeMethod<void>('setup', <String, dynamic>{'options': options});
  }

  Future<void> _setupAndroid(Map<String, dynamic> options) async {
    await _channel.invokeMethod<void>('setup', {'options': options});
  }

  Future<bool> setupPermissions() async {
    if (isIOS) {
      return true;
    }

    if (await hasPermissions()) {
      return true;
    }

    return await _requestPermissions();
  }

  Future<void> openPhoneAccounts() => _openPhoneAccounts();

  Future<void> _openPhoneAccounts() async {
    if (isIOS) {
      return;
    }
    await _channel.invokeMethod<void>('openPhoneAccounts');
  }

  Future<bool> _requestPermissions() async {
    if (isIOS) {
      return true;
    }
    var resp = await _channel.invokeMethod<bool>('requestPermissions');
    return resp ?? false;
  }

  FutureOr<bool> hasPermissions() async {
    if (isIOS) {
      return true;
    }
    var resp = await _channel.invokeMethod<bool>('hasPermissions');
    return resp ?? false;
  }

  Future<void> setForegroundServiceSettings(
    Map<String, String> settings,
  ) async {
    if (isIOS) {
      return;
    }
    await _channel.invokeMethod<void>('foregroundService', <String, dynamic>{
      'settings': {'foregroundService': settings}
    });
  }

  Future<void> eventListener(MethodCall call) async {
    print('[CallKeep] INFO: received event "${call.method}" ${call.arguments}');
    final data = call.arguments as Map<dynamic, dynamic>;
    switch (call.method) {
      case 'CallKeepDidReceiveStartCallAction':
        emit(CallKeepDidReceiveStartCallAction.fromMap(data));
        break;
      case 'CallKeepPerformAnswerCallAction':
        emit(CallKeepPerformAnswerCallAction.fromMap(data));
        break;
      case 'CallKeepPerformRejectCallAction':
        emit(CallKeepPerformRejectCallAction.fromMap(data));
        break;
      case 'CallKeepPerformEndCallAction':
        emit(CallKeepPerformEndCallAction.fromMap(data));
        break;
      case 'CallKeepDidActivateAudioSession':
        emit(CallKeepDidActivateAudioSession());
        break;
      case 'CallKeepDidDeactivateAudioSession':
        emit(CallKeepDidDeactivateAudioSession());
        break;
      case 'CallKeepDidDisplayIncomingCall':
        emit(CallKeepDidDisplayIncomingCall.fromMap(data));
        break;
      case 'CallKeepDidPerformSetMutedCallAction':
        emit(CallKeepDidPerformSetMutedCallAction.fromMap(data));
        break;
      case 'CallKeepDidToggleHoldAction':
        emit(CallKeepDidToggleHoldAction.fromMap(data));
        break;
      case 'CallKeepDidPerformDTMFAction':
        emit(CallKeepDidPerformDTMFAction.fromMap(data));
        break;
      case 'CallKeepProviderReset':
        emit(CallKeepProviderReset());
        break;
      case 'CallKeepCheckReachability':
        emit(CallKeepCheckReachability());
        break;
      case 'CallKeepDidLoadWithEvents':
        emit(CallKeepDidLoadWithEvents());
        break;
      case 'CallKeepPushKitToken':
        emit(CallKeepPushKitToken.fromMap(data));
        break;
    }
  }
}
