import Foundation
import UserNotifications

// 系统通知的薄封装
// 关键点：命令行自检没有 App Bundle，此时 UNUserNotificationCenter.current() 会抛 ObjC 异常（Swift 拦不住），
// 所以进入前必须先确认 bundleIdentifier 存在
enum ClipNotifier
{

    private enum ClipNotifierError: Error
    {
        case unsupportedEnvironment
    }

    // 当前环境能否使用系统通知
    static var isSupported: Bool
    {

        return Bundle.main.bundleIdentifier != nil && NSClassFromString("UNUserNotificationCenter") != nil

    }

    // 函数：请求通知授权
    // 说明：无 Bundle 时静默跳过，绝不抛异常
    static func requestAuthorization()
    {

        guard isSupported else
        {
            return
        }

        do
        {
            try deliverAuthorizationRequest()
        }
        catch
        {
            print("[CutBoardar] 通知授权请求被跳过: \(error)")
        }

    }

    // 函数：尽力发一条通知
    // 参数：title —— 标题；body —— 正文
    // 返回值：无；任何失败只打印，不影响主流程
    static func post(title: String, body: String)
    {

        do
        {
            try deliver(title: title, body: body)
        }
        catch
        {
            print("[CutBoardar] 通知发送被跳过: \(title)（\(error)）")
        }

    }

    private static func deliverAuthorizationRequest() throws
    {

        guard isSupported else
        {
            throw ClipNotifierError.unsupportedEnvironment
        }

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        {
            granted, error in

            if let error
            {
                print("[CutBoardar] 通知授权失败: \(error.localizedDescription)")
            }
            else if !granted
            {
                print("[CutBoardar] 用户未授予通知权限")
            }
        }

    }

    private static func deliver(title: String, body: String) throws
    {

        guard isSupported else
        {
            throw ClipNotifierError.unsupportedEnvironment
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)

        UNUserNotificationCenter.current().add(request)
        {
            error in

            if let error
            {
                print("[CutBoardar] 通知投递失败: \(error.localizedDescription)")
            }
        }

    }

}
