import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_nb_net/flutter_net.dart';
import 'package:get/get.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

class GithubVersionModel extends BaseNetModel {
  @override
  GithubVersionModel fromJson(Map<String, dynamic> json) {
    return GithubVersionModel.fromJson(json);
  }

  GithubVersionModel({
    this.version,
    this.body,
  });
  GithubVersionModel.fromJson(dynamic json) {
    version = json['tag_name'];
    body = json['body'];
  }

  String? version;
  String? body;
}

// 对版本进行对比，如果last > current 则返回true
bool compareVersion(String current, String last) {
  if (current.contains('v')) {
    current = current.substring(1);
  }
  if (last.contains('v')) {
    last = last.substring(1);
  }
  List<String> currentNumbers = current.split('.');
  List<String> lastNumbers = last.split('.');

  // 比较主版本号
  if (int.parse(lastNumbers[0]) > int.parse(currentNumbers[0])) {
    return true;
  } else if (int.parse(lastNumbers[0]) < int.parse(currentNumbers[0])) {
    return false;
  }

  // 比较次版本号
  if (int.parse(lastNumbers[1]) > int.parse(currentNumbers[1])) {
    return true;
  } else if (int.parse(lastNumbers[1]) < int.parse(currentNumbers[1])) {
    return false;
  }

  // 比较修订号
  if (int.parse(lastNumbers[2]) > int.parse(currentNumbers[2])) {
    return true;
  }

  return false;
}

Future<String> getCurrentVersion() async {
  if (kReleaseMode) {
    // String result = '';
    // if (Platform.isWindows) {
    //   try {
    //     rootBundle.loadString('assets/version.txt').then((value) {
    //       value = value.replaceAll('\r', '');
    //       value = value.replaceAll('\n', '');
    //       value = value.replaceAll('v', '');
    //       value = value.replaceAll('V', '');
    //       result = value;
    //     });
    //   } on Exception {
    //     result = 'v0.0.1';
    //   }
    //   return result;
    // }
    // return 'v0.0.1';
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    return 'v${packageInfo.version}';
  }
  return 'v0.0.1';
}

void showUpdateVersion(String content) {
  Get.dialog(Markdown(data: content));
}
