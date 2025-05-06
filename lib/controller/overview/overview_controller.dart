part of overview;

enum ScriptState {
  inactive, // 0
  running, // 递增
  warning,
  updating,
}

class OverviewController extends GetxController {
  WebSocketChannel? channel;
  int wsConnetCount = 0;

  String name;
  var scriptState = ScriptState.updating.obs;
  final running = const TaskItemModel('', '').obs;
  final pendings = <TaskItemModel>[].obs;
  final waitings = const <TaskItemModel>[].obs;

  // final log = ''.obs;
  // 修改log声明为可维护行数的结构
  final log = <String>[].obs; // 改为存储每行日志的列表

  final scrollController = ScrollController();
  final autoScroll = true.obs;

  double? savedScrollPosition; // 保存滚动位置

  void saveScrollPosition() {
    // 添加安全校验
    if (scrollController.hasClients) {
      savedScrollPosition = scrollController.position.pixels;
      debugPrint('Saved scroll position: $savedScrollPosition');
    } else {
      debugPrint(
          'Warning: Attempted to save position to unattached controller');
    }
  }

  void restoreScrollPosition() {
    if (savedScrollPosition != null) {
      // 确保在视图完成布局后执行
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scrollController.hasClients) { // 检查是否已附加
          scrollController.jumpTo(savedScrollPosition!);
        }
      });
    }
  }
  OverviewController({required this.name});

  @override
  void onInit() {
    print("创建控制器: $name");
    super.onInit();
  }

  @override
  Future<void> onReady() async {
    await wsConnet();
    super.onReady();
  }

  void activeScript() {
    if (scriptState.value != ScriptState.running) {
      scriptState.value = ScriptState.running;
      channel!.sink.add('start');
      clearLog();
    } else {
      scriptState.value = ScriptState.inactive;
      channel!.sink.add('stop');
    }
  }

  Future<void> wsConnet() async {
    try {
      String address = 'ws://${ApiClient().address}/ws/$name';
      if (address.contains('http://')) {
        address = address.replaceAll('http://', '');
      }
      printInfo(info: address);
      channel = WebSocketChannel.connect(Uri.parse(address));
    } on SocketException {
      printInfo(
          info:
          'Unhandled Exception: SocketException: Failed host lookup: http (OS Error: 不知道这样的主机。');
    } on Exception catch (e) {
      printError(info: e.toString());
    }
    await channel!.ready;
    channel!.stream.listen(wsListen, onDone: wsReconnet);
  }

  void wsListen(dynamic message) {
    if (message is! String) {
      printError(info: 'Websocket push data is not of type string and map');
      return;
    }
    if (!message.startsWith('{') || !message.endsWith('}')) {
      addLog(message);
      return;
    }
    Map<String, dynamic> data = json.decode(message);
    if (data.containsKey('state')) {
      scriptState.value = switch (data['state']) {
        0 => ScriptState.inactive,
        1 => ScriptState.running,
        2 => ScriptState.warning,
        3 => ScriptState.updating,
        _ => ScriptState.inactive,
      };
    } else if (data.containsKey('schedule')) {
      Map run = data['schedule']['running'];
      List<dynamic> pending = data['schedule']['pending'];

      List<dynamic> waiting = data['schedule']['waiting'];

      if (run.isNotEmpty) {
        running.value = TaskItemModel(run['name'], run['next_run']);
      } else {
        running.value = const TaskItemModel('', '');
      }
      pendings.value = [];
      for (var element in pending) {
        pendings.add(TaskItemModel(element['name'], element['next_run']));
      }
      waitings.value = [];
      for (var element in waiting) {
        waitings.add(TaskItemModel(element['name'], element['next_run']));
      }
    }
  }

  void wsReconnet() {
    wsConnetCount += 1;
    if (wsConnetCount > 10) {
      printError(info: "WebSocket reconnect failed");
      printError(info: "WebSocket is closed");
      printError(info: 'WebSocket reconnect is more than 10 times');
      return;
    }
    printInfo(info: "Socket is closed");
    wsConnet();
  }

  // void addLog(String message) {
  //   log.value += message;
  // }
  //
  // void clearLog() {
  //   log.value = '';
  // }


// 修改后的 addLog 方法（OverviewController 中）
  void addLog(String message) {
    // 处理多行日志（兼容 \n 换行）
    final lines = message
        .replaceAll('\r\n', '\n')  // 统一换行符
        .split('\n')               // 分割为独立行
        .where((line) => line.isNotEmpty) // 过滤空行
        .toList();

    // 批量更新日志列表（单次响应式更新）
    log.assignAll([...log, ...lines]);

    // 日志截断优化（保持高性能）
    if (log.length > 2000) {
      log.assignAll(log.skip(log.length - 2000).toList());
    }

    // 立即触发滚动到底部
    _scheduleAutoScroll();
  }

// 新增滚动控制方法
  void _scheduleAutoScroll() {
    if (autoScroll.value &&
        scrollController.hasClients &&
        !scrollController.position.outOfRange) {
      // 零延迟硬跳转
      scrollController.jumpTo(scrollController.position.maxScrollExtent);
    }
  }

// 在控制器销毁时增加保护
  @override
  void onClose() {
    scrollController.dispose(); // 必须释放控制器
    super.onClose();
  }

  void clearLog() {
    log.clear();
  }


}
