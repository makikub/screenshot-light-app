import Carbon

/// グローバルホットキー（⌘⇧S）を Carbon API で登録する
///
/// Carbon の `RegisterEventHotKey` はアクセシビリティ権限なしで動作し、
/// アプリがバックグラウンドでもホットキーを受け取れる。
final class HotKeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    func register(onHotKey: @escaping () -> Void) {
        hotKeyAction = onHotKey

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            hotKeyCallback,
            1,
            &eventType,
            nil,
            &eventHandlerRef
        )

        // ⌘⇧S を登録
        let hotKeyID = EventHotKeyID(
            signature: OSType(0x53415053),
            id: 1
        )
        RegisterEventHotKey(
            UInt32(kVK_ANSI_S),
            UInt32(cmdKey | shiftKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let ref = eventHandlerRef {
            RemoveEventHandler(ref)
            eventHandlerRef = nil
        }
        hotKeyAction = nil
    }
}

// MARK: - Carbon callback

/// C 関数ポインタから呼び出せるようモジュールレベルに配置
private var hotKeyAction: (() -> Void)?

private func hotKeyCallback(
    _: EventHandlerCallRef?,
    _: EventRef?,
    _: UnsafeMutableRawPointer?
) -> OSStatus {
    hotKeyAction?()
    return noErr
}
