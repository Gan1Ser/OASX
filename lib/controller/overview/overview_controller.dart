part of overview;

enum ScriptState {
  inactive, // 0
  running, // 递增
  warning,
  updating,
}

class OverviewController extends GetxController {
  WebSocketChannel? channel;
  int wsConnectCount = 0; // 原有重连计数器（注意拼写修正为 Connect）

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
  bool _isConnecting = false;
  bool _isConnected = false;

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
    // 添加滚动监听器
    scrollController.addListener(_scrollListener);
    super.onInit();
  }

  @override
  Future<void> onReady() async {
    await wsConnect();
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

  Future<void> wsConnect() async {
    if (_isConnecting || _isConnected) {
      return;
    }

    _isConnecting = true;
    _isConnected = false; // 明确设置为未连接状态

    try {
      String address = 'ws://${ApiClient().address}/ws/$name';
      if (address.contains('http://') || address.contains('https://')) {
        address = address.replaceAll('http://', '').replaceAll('https://', '');
      }
      print("尝试连接: $address");

      // 创建WebSocket通道
      channel = WebSocketChannel.connect(Uri.parse(address));
      // 等待连接就绪
      await channel!.ready;

      // 连接成功后的处理
      _isConnected = true;
      _isConnecting = false;
      wsConnectCount = 0; // 重置重连计数器
      print("WebSocket连接成功");

      // 确保通道有效
      if (channel != null) {
        await channel!.ready;
        channel!.stream.listen(wsListen, onDone: wsReconnet);
      }
    }catch (e) {
      print("连接异常: $e");
      _isConnecting = false;
      _isConnected = false;
      wsReconnet();
    }

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
    // 首先检查是否已经正在重连或已连接
    if (_isConnecting || _isConnected) {
      return;
    }
    wsConnectCount += 1;
    // if (wsConnectCount > 10) {
    //   printError(info: "WebSocket reconnect failed");
    //   printError(info: "WebSocket is closed");
    //   printError(info: 'WebSocket reconnect is more than 10 times');
    //   wsConnectCount = 0; // 重置计数器
    //   return;
    // }
    print("Socket is closed, $wsConnectCount 次重连");
    // 设置连接状态，防止并发重连
    _isConnecting = true;

    // 添加延迟重连，避免频繁重连导致控制器不断重建
    Future.delayed(const Duration(milliseconds: 1000), () {
      // 在实际重连前再次检查状态
      if (!_isConnected) {
        wsConnect();
      }
    });
  }

  // 滚动监听器
  void _scrollListener() {
    if (scrollController.hasClients) {
      // 检查是否滚动到底部
      if (scrollController.position.pixels >= scrollController.position.maxScrollExtent - 10) {
        // 如果接近底部，启用自动滚动
        if (!autoScroll.value) {
          autoScroll.value = true;
        }
      } else {
        // 如果不在底部，禁用自动滚动
        if (autoScroll.value) {
          autoScroll.value = false;
        }
      }
    }
  }

  // void addLog(String message) {
  //   log.value += message;
  // }
  //
  // void clearLog() {
  //   log.value = '';
  // }


    void addLog(String message) {
      // 直接添加单行日志（假设message已经是一行）
      log.add(message);

      // 更高效的日志截断方式
      if (log.length > 2000) {
        log.removeRange(0, log.length - 500);
      }

    if (autoScroll.value) {  // 1. 检查是否启用自动滚动
      WidgetsBinding.instance.addPostFrameCallback((_) {  // 2. 等待下一帧绘制完成
        if (scrollController.hasClients) {
          scrollController.animateTo( // 3. 执行滚动动画
            scrollController.position.maxScrollExtent, // 4. 滚动目标位置
            duration: const Duration(milliseconds: 1), // 5. 动画持续时间
            curve: Curves.easeOut, // 6. 动画曲线
          );
        }
      });
    }
  }


// 在控制器销毁时增加保护
  @override
  void onClose() {
    _isConnected = false;
    _isConnecting = false;
    channel?.sink.close(); // 关闭WebSocket连接
    scrollController.removeListener(_scrollListener); // 移除滚动监听器
    scrollController.dispose(); // 必须释放控制器
    super.onClose();
  }

  void clearLog() {
    log.clear();
  }


}
