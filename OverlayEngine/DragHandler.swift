// DragHandler.swift
// iGet — OverlayEngine
//
// NSWindow tabanlı overlay widget'lar için sürükleme (drag) yöneticisi.
// Her OverlayWidgetWindow kendi DragHandler örneğini tutar.
//
// Çalışma mantığı:
//   • mouseDown  → başlangıç ofsetini hesapla
//   • mouseDragged → pencereyi taşı (setFrameOrigin)
//   • mouseUp    → yeni konumu SharedStorage'a yaz
//
// Target Membership: iGet
//
// Organization: TwoBit-Dev

import AppKit
import Foundation

// MARK: - DragHandlerDelegate

public protocol DragHandlerDelegate: AnyObject {
    /// Sürükleme tamamlandığında çağrılır.
    func dragHandler(_ handler: DragHandler, didEndAt position: CGPoint, for widgetID: UUID)
}

// MARK: - DragHandler

/// NSView'e eklenen mouse-event hook'ları aracılığıyla
/// overlay penceresini sürüklenebilir yapar.
public final class DragHandler {

    // MARK: Properties

    public weak var delegate: DragHandlerDelegate?

    private weak var window: NSWindow?
    private let widgetID: UUID

    /// Fare butonuna basıldığındaki pencere-içi offset (ekran koordinatları)
    private var dragOffset: CGPoint = .zero

    /// Sürükleme aktif mi?
    private(set) public var isDragging = false

    // MARK: Init

    public init(window: NSWindow, widgetID: UUID) {
        self.window   = window
        self.widgetID = widgetID
    }

    // MARK: - Mouse Event Handlers
    // OverlayWidgetView'den çağrılır (NSView override veya NSGestureRecognizer)

    /// `NSView.mouseDown(with:)` override'ından çağrılmalı.
    public func handleMouseDown(with event: NSEvent) {
        guard let window else { return }

        // Fare konumunu ekran koordinatlarına çevir
        let mouseLocation = NSEvent.mouseLocation
        let frame         = window.frame

        // Pencerenin sol-alt köşesinden farkı sakla
        dragOffset = CGPoint(
            x: mouseLocation.x - frame.origin.x,
            y: mouseLocation.y - frame.origin.y
        )
        isDragging = true
    }

    /// `NSView.mouseDragged(with:)` override'ından çağrılmalı.
    public func handleMouseDragged(with event: NSEvent) {
        guard isDragging, let window else { return }

        let mouseLocation = NSEvent.mouseLocation

        // Yeni pencere orijini = fare konumu − başlangıç ofseti
        var newOrigin = CGPoint(
            x: mouseLocation.x - dragOffset.x,
            y: mouseLocation.y - dragOffset.y
        )

        // Ekran sınırları içinde tut
        newOrigin = clamp(newOrigin, in: window)

        window.setFrameOrigin(newOrigin)
    }

    /// `NSView.mouseUp(with:)` override'ından çağrılmalı.
    public func handleMouseUp(with event: NSEvent) {
        guard isDragging, let window else { return }
        isDragging = false

        let finalOrigin = window.frame.origin

        // SharedStorage'a kaydet
        let position = WidgetPosition(x: finalOrigin.x, y: finalOrigin.y)
        SharedStorage.shared.updatePosition(position, for: widgetID)

        // Delegate'e bildir
        delegate?.dragHandler(self, didEndAt: finalOrigin, for: widgetID)
    }

    // MARK: - Helpers

    /// Verilen orijini ekran sınırları içinde tutar.
    private func clamp(_ origin: CGPoint, in window: NSWindow) -> CGPoint {
        guard let screen = window.screen ?? NSScreen.main else { return origin }

        let screenFrame = screen.visibleFrame
        let winFrame    = window.frame

        let minX = screenFrame.minX
        let maxX = screenFrame.maxX - winFrame.width
        let minY = screenFrame.minY
        let maxY = screenFrame.maxY - winFrame.height

        return CGPoint(
            x: max(minX, min(origin.x, maxX)),
            y: max(minY, min(origin.y, maxY))
        )
    }
}

// MARK: - DraggableView

/// Sürükleme desteği kazandırılmış temel NSView.
/// Overlay widget view'leri bu sınıftan miras alır.
open class DraggableView: NSView {

    // MARK: Properties

    public var dragHandler: DragHandler?

    // MARK: NSView Overrides

    open override var mouseDownCanMoveWindow: Bool { false }
    open override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    open override func mouseDown(with event: NSEvent) {
        dragHandler?.handleMouseDown(with: event)
    }

    open override func mouseDragged(with event: NSEvent) {
        dragHandler?.handleMouseDragged(with: event)
    }

    open override func mouseUp(with event: NSEvent) {
        dragHandler?.handleMouseUp(with: event)
    }
}
