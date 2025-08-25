import os
import requests
import json


os.chdir(os.path.join(os.path.dirname(__file__), '../'))
print(os.getcwd())


def get_github_latest_version():
    """获取GitHub上的最新标签"""
    try:
        # 改用获取所有标签的API，然后选择最新的一个
        url = "https://api.github.com/repos/ljxun/OASX/tags"
        response = requests.get(url)
        if response.status_code == 200:
            data = json.loads(response.text)
            # 确保有标签存在
            if data and len(data) > 0:
                # 返回最新的标签(第一个就是最新的)
                return data[0]["name"]
        return None
    except Exception as e:
        print(f"获取GitHub最新标签失败: {e}")
        return None


if __name__ == '__main__':
    # 获取GitHub最新版本
    github_version = get_github_latest_version()

    with open('./CHANGELOG.md', 'r', encoding='utf-8') as file:
        log = file.read()
        start_index = log.find('# v')
        # 检查是否找到版本标记
        if start_index != -1:
            end_index = log.find('# v', start_index+1)
            change_latest = log[start_index: end_index]

            # 提取本地最新版本号
            first_line_end = log.find('\n', start_index)
            local_version = log[start_index+2 : first_line_end].strip()

            # 如果GitHub版本与本地版本不一致，添加提示信息
            if github_version != local_version:
                change_latest = f"# {github_version}\n无最新更新日志\n\n"
        else:
            # 如果没有找到版本标记，使用默认内容
            change_latest = f"# {github_version if github_version else 'v0.0.0'}\n无最新更新日志\n" if github_version else "无最新更新日志\n"

    print(change_latest)
    with open('CHANGELATEST.md', 'w', encoding='utf-8') as file:
        file.write(change_latest)
