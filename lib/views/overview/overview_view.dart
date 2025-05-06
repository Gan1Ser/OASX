library overview;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:styled_widget/styled_widget.dart';
import 'package:easy_rich_text/easy_rich_text.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:oasx/api/api_client.dart';
import 'package:oasx/views/nav/view_nav.dart';
import 'package:oasx/comom/i18n_content.dart';

part '../../controller/overview/overview_controller.dart';
part '../../controller/overview/taskitem_model.dart';
part './taskitem_view.dart';

class Overview extends StatelessWidget {
  const Overview({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {

    // 获取当前选中的脚本名称（从导航控制器）
    final NavCtrl navCtrl = Get.find<NavCtrl>();
    final String name = navCtrl.selectedScript.value;

    // 动态注册控制器（如果不存在）
    if (!Get.isRegistered<OverviewController>(tag: name)) {
      Get.create<OverviewController>(
            () => OverviewController(name: name),
        tag: name,
        permanent: true, // 关键：保持实例长期存活
      );
    }

    // return const Text("xxx");
    if (context.mediaQuery.orientation == Orientation.portrait) {
      // 竖方向
      return SingleChildScrollView(
        child: <Widget>[
          _scheduler(),
          _running(),
          _pendings(),
          _waitings().constrained(maxHeight: 200),
          _logTitle().paddingOnly(left: 10),
          _log(context).constrained(maxHeight: 500).paddingOnly(left: 10)
        ].toColumn(),
      );
    } else {
      //横方向
      return <Widget>[
        // 左边
        <Widget>[
          _scheduler(),
          _running(),
          _pendings(),
          Expanded(child: _waitings()),
        ].toColumn().constrained(width: 300),
        // 右边
        <Widget>[_logTitle(), _log(context).expanded()]
            .toColumn(crossAxisAlignment: CrossAxisAlignment.start)
            .expanded()
      ].toRow();
    }
  }

  Widget _scheduler() {
    NavCtrl navCtroler = Get.find<NavCtrl>();
    return GetX<OverviewController>(
        tag: navCtroler.selectedScript.value,
        builder: (OverviewController cont) {
          OverviewController controller = Get.find<OverviewController>(
              tag: navCtroler.selectedScript.value);
          Widget stateText = switch (controller.scriptState.value) {
            ScriptState.running => const Text("Running"),
            ScriptState.inactive => const Text("Inactive"),
            ScriptState.warning => const Text("Warning"),
            ScriptState.updating => const Text("Updating"),
          };
          Widget stateSpinKit = switch (controller.scriptState.value) {
            ScriptState.running => const SpinKitChasingDots(
                color: Colors.green,
                size: 22,
              ),
            ScriptState.inactive =>
              const Icon(Icons.donut_large, size: 26, color: Colors.grey),
            ScriptState.warning =>
              const SpinKitDoubleBounce(color: Colors.orange, size: 26),
            ScriptState.updating => const Icon(Icons.browser_updated_rounded,
                size: 26, color: Colors.blue),
          };
          return <Widget>[
            Text(I18n.scheduler.tr,
                textAlign: TextAlign.left, style: Get.textTheme.titleMedium),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                stateSpinKit,
                IconButton(
                  onPressed: () => {controller.activeScript()},
                  icon: const Icon(Icons.power_settings_new_rounded),
                  isSelected:
                  controller.scriptState.value == ScriptState.running,
                ),
              ],
            ),

            // stateText,
          ]
              .toRow(mainAxisAlignment: MainAxisAlignment.spaceBetween)
              .constrained(height: 48)
              .paddingOnly(left: 8, right: 8)
              .card(margin: const EdgeInsets.fromLTRB(10, 0, 10, 10));
        });
  }

  Widget _running() {
    NavCtrl navCtroler = Get.find<NavCtrl>();
    return GetX<OverviewController>(
        tag: navCtroler.selectedScript.value,
        builder: (OverviewController controller) {
          OverviewController controller = Get.find<OverviewController>(
              tag: navCtroler.selectedScript.value);
          return <Widget>[
            Text(I18n.running.tr,
                textAlign: TextAlign.left, style: Get.textTheme.titleMedium),
            const Divider(),
            TaskItemView.fromModel(controller.running.value)
          ]
              .toColumn(crossAxisAlignment: CrossAxisAlignment.start)
              .padding(top: 8, bottom: 0, left: 8, right: 8)
              .card(margin: const EdgeInsets.fromLTRB(10, 0, 10, 10));
        });
  }

  Widget _pendings() {
    NavCtrl navCtroler = Get.find<NavCtrl>();
    return GetX<OverviewController>(
        tag: navCtroler.selectedScript.value,
        builder: (OverviewController controller) {
          OverviewController controller = Get.find<OverviewController>(
              tag: navCtroler.selectedScript.value);
          return <Widget>[
            Text(I18n.pending.tr,
                textAlign: TextAlign.left, style: Get.textTheme.titleMedium),
            const Divider(),
            SizedBox(
                height: 140,
                child: ListView.builder(
                    itemBuilder: (context, index) =>
                        TaskItemView.fromModel(controller.pendings[index]),
                    itemCount: controller.pendings.length))
          ]
              .toColumn(crossAxisAlignment: CrossAxisAlignment.start)
              .padding(top: 8, bottom: 0, left: 8, right: 8)
              .card(margin: const EdgeInsets.fromLTRB(10, 0, 10, 10));
        });
  }

  Widget _waitings() {
    NavCtrl navCtroler = Get.find<NavCtrl>();
    return GetX<OverviewController>(
        tag: navCtroler.selectedScript.value,
        builder: (OverviewController controller) {
          OverviewController controller = Get.find<OverviewController>(
              tag: navCtroler.selectedScript.value);
          return <Widget>[
            Text(I18n.waiting.tr,
                textAlign: TextAlign.left, style: Get.textTheme.titleMedium),
            const Divider(),
            Expanded(
                child: ListView.builder(
                    itemBuilder: (context, index) =>
                        TaskItemView.fromModel(controller.waitings[index]),
                    itemCount: controller.waitings.length))
          ]
              .toColumn(
                crossAxisAlignment: CrossAxisAlignment.start,
              )
              .paddingAll(8)
              .card(margin: const EdgeInsets.fromLTRB(10, 0, 10, 10));
        });
  }

  Widget _logTitle() {
    NavCtrl navCtrl = Get.find();
    return <Widget>[
      Text(I18n.log.tr,
          textAlign: TextAlign.left, style: Get.textTheme.titleMedium),
      Obx(() {
        final controller = Get.find<OverviewController>(tag: navCtrl.selectedScript.value);
        return Row(
          children: [
            Switch(
              value: controller.autoScroll.value,
              onChanged: (value) => controller.autoScroll.value = value,
            ),
            TextButton(
              onPressed: () => controller.clearLog(),
              child: Text(I18n.clear_log.tr),
            ),
          ],
        );
      }),
    ]
        .toRow(mainAxisAlignment: MainAxisAlignment.spaceBetween)
        .paddingAll(8)
        .card(margin: const EdgeInsets.fromLTRB(0, 0, 10, 10));
  }

  Widget _log(BuildContext context) {
    NavCtrl navCtroler = Get.find<NavCtrl>();
    return GetX<OverviewController>(
      tag: navCtroler.selectedScript.value,
      builder: (OverviewController controller) {
        OverviewController controller = Get.find<OverviewController>(tag: navCtroler.selectedScript.value);
        // print('Building log for ${controller.name} with scroll: ${controller.scrollController.hashCode}');
        return Container(
            margin: const EdgeInsets.fromLTRB(0, 0, 10, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: Get.theme.cardColor,
            ),
            child: ListView.builder(
              controller: controller.scrollController,
              itemCount: controller.log.length,
              reverse: false, // 保持最新日志在底部
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 1), // 减小垂直间距
                child: EasyRichText(
                  controller.log[index], // 逐行处理日志
                  patternList: _buildPatterns(),
                  selectable: true,
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                  defaultStyle: _selectStyle(context),
                ),
              ),
            ) .paddingAll(5)
                .constrained(width: double.infinity, height: double.infinity)
                .card(margin: const EdgeInsets.fromLTRB(0, 0, 10, 10))
        );
      },
    );
  }

  // 样式配置抽离为独立方法
  List<EasyRichTextPattern> _buildPatterns() {
    return
      [
        // INFO
        const EasyRichTextPattern(
          targetString: 'INFO',
          style: TextStyle(
            color: Color.fromARGB(255, 55, 109, 136),
            fontFeatures: [FontFeature.tabularFigures()],
          ),
          suffixInlineSpan: TextSpan(
              style: TextStyle(
                fontFeatures: [FontFeature.tabularFigures()],
              ),
              text: '  '),
        ),
        // WARNING
        const EasyRichTextPattern(
          targetString: 'WARNING',
          style: TextStyle(
            color: Colors.yellow,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
          suffixInlineSpan: TextSpan(
              style: TextStyle(
                fontFeatures: [FontFeature.tabularFigures()],
              ),
              text: ''),
        ),
        const EasyRichTextPattern(
          targetString: 'WARN',
          style: TextStyle(
            color: Colors.yellow,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
          suffixInlineSpan: TextSpan(
              style: TextStyle(
                fontFeatures: [FontFeature.tabularFigures()],
              ),
              text: ' '),
        ),
        // ERROR
        const EasyRichTextPattern(
          targetString: 'ERROR',
          style: TextStyle(
            color: Colors.red,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
          suffixInlineSpan: TextSpan(
              style: TextStyle(
                fontFeatures: [FontFeature.tabularFigures()],
              ),
              text: ''),
        ),
        // CRITICAL
        const EasyRichTextPattern(
          targetString: 'CRITICAL',
          style: TextStyle(
            color: Colors.red,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
          suffixInlineSpan: TextSpan(text: '   '),
        ),
        // 时间的
        const EasyRichTextPattern(
          targetString: r'(\d{2}:\d{2}:\d{2}\.\d{3})',
          style: TextStyle(
            color: Colors.cyan,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        // 粗体
        const EasyRichTextPattern(
          targetString: r'[\{\[\(\)\]\}]',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        // True
        const EasyRichTextPattern(
            targetString: 'True',
            style: TextStyle(color: Colors.lightGreen)),
        // False
        const EasyRichTextPattern(
            targetString: 'False',
            style: TextStyle(color: Colors.red)),
        // None
        const EasyRichTextPattern(
            targetString: 'None',
            style: TextStyle(color: Colors.purple)),
        // 路径Path
        // EasyRichTextPattern(
        //     targetString: r'([A-Za-z]\:)|.)?\B([\/\\][\w\.\-\_\+]+)*[\/\\]',
        //     style: const TextStyle(
        //         color: Colors.purple, fontStyle: FontStyle.italic)),
        // 分割线
        const EasyRichTextPattern(
          targetString: r'(══*══)|(──*──)',
          style: TextStyle(color: Colors.lightGreen),
        )
      ];
  }


  // 文字样式选择方法
  TextStyle _selectStyle(BuildContext context) {
    return context.mediaQuery.orientation == Orientation.portrait
        ? Get.textTheme.bodySmall!
        : Get.textTheme.titleSmall!;
  }
}
