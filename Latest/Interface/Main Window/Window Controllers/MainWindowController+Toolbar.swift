//
//  MainWindowController+Toolbar.swift
//  Latest
//
//  Created by Max Langer on 11.10.25.
//  Copyright © 2025 Max Langer. All rights reserved.
//

import AppKit

extension MainWindowController: NSToolbarDelegate {
	
	// MARK: - Toolbar Delegate
	
	func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
		var items: [NSToolbarItem.Identifier] = [
			.flexibleSpace,
			.progressIndicatorItem,
			.checkForUpdatesActionItem,
			.updateAllActionItem
		]
		
		// Items sit in sidebar
		items.append(.sidebarTrackingSeparator)
		
		return items
	}
	
	func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
		toolbarDefaultItemIdentifiers(toolbar)
	}
	
	func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
		let item = NSToolbarItem(itemIdentifier: itemIdentifier)
		
		switch itemIdentifier {
		case .progressIndicatorItem:
			item.view = progressIndicator
		case .checkForUpdatesActionItem:
			item.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: nil)
			item.toolTip = NSLocalizedString("CheckForUpdatesToolbarItemToolTip", comment: "Tool tip of a toolbar button that checks for updates")
			item.action = #selector(reload(_:))
		case .updateAllActionItem:
			item.image = NSImage(named: "custom.arrow.down.square.stack")
			item.toolTip = NSLocalizedString("UpdateAllToolbarItemToolTip", comment: "Tool tip of a toolbar button that performs updates for all apps with update available")
			item.action = #selector(updateAll(_:))
		default:
			return nil
		}
		
		updateVisibility(of: item)
		return item
	}
	
	/// Shows the progress indicator in place of the reload button while checking for updates.
	func updateToolbarItemVisibility() {
		self.window?.toolbar?.items.forEach(updateVisibility(of:))
	}
	
	private func updateVisibility(of item: NSToolbarItem) {
		// Hide the item itself, a hidden view would leave an empty slot in the glass group
		guard #available(macOS 15.0, *) else { return }
		
		switch item.itemIdentifier {
		case .progressIndicatorItem:
			item.isHidden = !isRunningUpdateCheck
		case .checkForUpdatesActionItem:
			item.isHidden = isRunningUpdateCheck
		default:
			break
		}
	}
	
}

private extension NSToolbarItem.Identifier {
	/// The item showing the progress indicator.
	static let progressIndicatorItem = NSToolbarItem.Identifier("latest.reloadProgressIndicatorItem")

	/// Action for checking for updates
	static let checkForUpdatesActionItem = NSToolbarItem.Identifier("latest.checkForUpdatesActionItem")
	
	/// Action for updating all apps.
	static let updateAllActionItem = NSToolbarItem.Identifier("latest.updateAllActionItem")
}
