//
//  Installer.swift
//  Installer
//
//  Created by Max Langer on 06.01.26.
//  Copyright © 2026 Max Langer. All rights reserved.
//

import Foundation

/// The implementation of the install helper.
class UpdateInstaller: NSObject, UpdateInstallerProtocol {
	func performInstallation(ofPackageAt url: URL, targetURL: String, receiptData: Data, receiptURL: URL, reply: @escaping ((any Error)?) -> Void) {
		do {
			// This runs as root, so never act on paths outside of what an App Store install needs
			let request = try Request(packageURL: url, targetPath: targetURL, receiptURL: receiptURL)

			// Install app
			let (success, output) = try runInstaller(packagePath: request.packagePath, targetPath: request.targetPath)
			guard success else {
				reply(Self.error(output))
				return
			}

			// Insert receipt
			let fileManager = FileManager.default
			let attributes: [FileAttributeKey: Any] = [.ownerAccountID: 0, .groupOwnerAccountID: 0, .posixPermissions: 0o755]
			let receiptPath = request.receiptURL.path(percentEncoded: false)

			if fileManager.fileExists(atPath: receiptPath) {
				try fileManager.removeItem(at: request.receiptURL)
			} else {
				try fileManager.createDirectory(at: request.receiptURL.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: attributes)
			}

			// A symlink inside the bundle must not redirect the write elsewhere
			try request.verifyReceiptLocation()

			try receiptData.write(to: request.receiptURL, options: .atomic)
			try fileManager.setAttributes(attributes, ofItemAtPath: receiptPath)
		} catch {
			reply(error)
			return
		}

		// Install successful. The package is removed by the app, which owns it.
		reply(nil)
	}

	/// Runs the system installer without a shell, so paths are never interpreted as commands.
	private func runInstaller(packagePath: String, targetPath: String) throws -> (success: Bool, output: String) {
		let process = Process()
		process.executableURL = URL(fileURLWithPath: "/usr/sbin/installer")
		process.arguments = ["-pkg", packagePath, "-target", targetPath]

		let pipe = Pipe()
		process.standardOutput = pipe
		process.standardError = pipe

		try process.run()

		// Read before waiting, a full pipe would block the installer forever
		let data = pipe.fileHandleForReading.readDataToEndOfFile()
		process.waitUntilExit()

		let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
		let success = (process.terminationStatus == 0)

		return (success, output)
	}

	fileprivate static func error(_ description: String) -> NSError {
		NSError(domain: "LatestInstallerErrorDomain", code: 0, userInfo: [NSLocalizedDescriptionKey: description])
	}
}

/// A validated installation request.
private struct Request {
	let packagePath: String
	let targetPath: String
	let receiptURL: URL

	init(packageURL: URL, targetPath: String, receiptURL: URL) throws {
		let packagePath = packageURL.path(percentEncoded: false)
		guard packageURL.isFileURL, packageURL.pathExtension == "pkg", Self.isPlainAbsolutePath(packagePath) else {
			throw UpdateInstaller.error("Invalid package location.")
		}

		// The target must be an existing app bundle
		var isDirectory: ObjCBool = false
		guard Self.isPlainAbsolutePath(targetPath), targetPath.hasSuffix(".app"),
			  FileManager.default.fileExists(atPath: targetPath, isDirectory: &isDirectory), isDirectory.boolValue else {
			throw UpdateInstaller.error("Invalid install location.")
		}

		// The receipt may only be written to its fixed place within that bundle
		let expectedReceiptURL = URL(fileURLWithPath: targetPath + "/Contents/_MASReceipt/receipt")
		guard receiptURL.isFileURL, Self.isPlainAbsolutePath(receiptURL.path(percentEncoded: false)),
			  receiptURL.standardizedFileURL.path(percentEncoded: false) == expectedReceiptURL.standardizedFileURL.path(percentEncoded: false) else {
			throw UpdateInstaller.error("Invalid receipt location.")
		}

		self.packagePath = packagePath
		self.targetPath = targetPath
		self.receiptURL = expectedReceiptURL
	}

	/// Ensures the receipt directory is located within the app bundle on disk.
	func verifyReceiptLocation() throws {
		// Created without a trailing slash, directory URLs would otherwise never match
		let directory = URL(fileURLWithPath: targetPath + "/Contents/_MASReceipt", isDirectory: false)
		let bundle = URL(fileURLWithPath: targetPath, isDirectory: false).resolvingSymlinksInPath().path(percentEncoded: false)

		guard directory.resolvingSymlinksInPath().path(percentEncoded: false) == bundle + "/Contents/_MASReceipt" else {
			throw UpdateInstaller.error("Invalid receipt location.")
		}
	}

	/// Whether the path is absolute and free of control characters and relative components.
	private static func isPlainAbsolutePath(_ path: String) -> Bool {
		path.hasPrefix("/")
			&& !path.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) })
			&& !path.split(separator: "/", omittingEmptySubsequences: false).contains(where: { $0 == ".." || $0 == "." })
	}
}
