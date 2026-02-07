//
//  SplitVC.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 25.02.24.
//  Copyright (c) 2024 Maximilian Bauer. All rights reserved.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import AmperfyKit
import UIKit

import SwiftUI

// MARK: - SecondaryContainerVC

/// A container that holds the main content on the left and an optional
/// inspector panel (lyrics / queue) on the right.  Uses frame-based layout
/// (viewDidLayoutSubviews) so the content view's frame is set directly —
/// guaranteeing that all child views (including compositional-layout
/// collection views) see the correct width.
///
/// The inspector width is user-adjustable via a drag handle on its left edge
/// and the chosen width is persisted across launches.
class SecondaryContainerVC: UIViewController {
  private(set) var contentVC: UIViewController
  private var inspectorVC: UIViewController?
  private var inspectorContainer: UIView?

  // MARK: Inspector width (user-adjustable, persisted)

  private static let inspectorWidthKey = "SecondaryContainerVC.inspectorWidth"
  private static let defaultInspectorWidth: CGFloat = SplitVC.inspectorWidth
  private static let minInspectorWidth: CGFloat = 200
  private static let maxInspectorWidth: CGFloat = 600

  /// The current inspector panel width.
  private var currentInspectorWidth: CGFloat {
    didSet {
      UserDefaults.standard.set(currentInspectorWidth, forKey: Self.inspectorWidthKey)
    }
  }

  /// The width reported to the parent (SplitVC) for miniPlayer insets etc.
  var activeInspectorWidth: CGFloat {
    inspectorVC != nil ? currentInspectorWidth : 0
  }

  // MARK: Inspector vertical split (user-adjustable, persisted)

  private static let inspectorSplitRatioKey = "SecondaryContainerVC.inspectorSplitRatio"
  private static let defaultSplitRatio: CGFloat = 0.5
  private static let minSplitRatio: CGFloat = 0.15
  private static let maxSplitRatio: CGFloat = 0.85

  /// The fraction of the inspector height used by the primary (queue) panel.
  /// The secondary (lyrics) panel gets the rest.
  private var inspectorSplitRatio: CGFloat {
    didSet {
      UserDefaults.standard.set(inspectorSplitRatio, forKey: Self.inspectorSplitRatioKey)
    }
  }

  // MARK: Drag handles

  private var dragHandle: UIView?
  private var verticalDragHandle: UIView?
  /// The inspector width at the start of a drag gesture.
  private var dragStartWidth: CGFloat = 0
  /// The split ratio at the start of a vertical drag gesture.
  private var dragStartSplitRatio: CGFloat = 0

  // MARK: Init

  init(contentVC: UIViewController) {
    self.contentVC = contentVC
    let storedWidth = UserDefaults.standard.double(forKey: Self.inspectorWidthKey)
    self.currentInspectorWidth = storedWidth > 0
      ? CGFloat(storedWidth).clamped(to: Self.minInspectorWidth...Self.maxInspectorWidth)
      : Self.defaultInspectorWidth
    let storedRatio = UserDefaults.standard.double(forKey: Self.inspectorSplitRatioKey)
    self.inspectorSplitRatio = storedRatio > 0
      ? CGFloat(storedRatio).clamped(to: Self.minSplitRatio...Self.maxSplitRatio)
      : Self.defaultSplitRatio
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: Lifecycle

  override func viewDidLoad() {
    super.viewDidLoad()
    view.clipsToBounds = true
    installContent(contentVC)
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    layoutChildren()
  }

  // MARK: Layout

  /// Recalculates frames for content, inspector, and drag handle.
  private func layoutChildren() {
    let bounds = view.bounds
    if let inspectorContainer {
      // Clamp inspector width to available space
      let maxAllowed = bounds.width - 200 // leave at least 200pt for content
      let iw = min(currentInspectorWidth, max(maxAllowed, Self.minInspectorWidth))
      let contentWidth = max(bounds.width - iw, 0)

      contentVC.view.frame = CGRect(x: 0, y: 0, width: contentWidth, height: bounds.height)
      inspectorContainer.frame = CGRect(
        x: contentWidth, y: 0,
        width: iw, height: bounds.height
      )

      // Layout inspector children (primary + optional secondary stacked vertically)
      if let secondaryVC = inspectorSecondaryVC {
        let totalHeight = inspectorContainer.bounds.height
        let topHeight = (totalHeight * inspectorSplitRatio).rounded()
        let bottomHeight = totalHeight - topHeight
        inspectorVC?.view.frame = CGRect(x: 0, y: 0, width: iw, height: topHeight)
        secondaryVC.view.frame = CGRect(x: 0, y: topHeight, width: iw, height: bottomHeight)

        // Position vertical drag handle at the split boundary
        let vHandleHeight: CGFloat = 8
        verticalDragHandle?.frame = CGRect(
          x: 0,
          y: topHeight - vHandleHeight / 2,
          width: iw,
          height: vHandleHeight
        )
      } else {
        // Single VC fills the inspector
        inspectorVC?.view.frame = inspectorContainer.bounds
      }

      // Position drag handle on the left edge of the inspector
      let handleWidth: CGFloat = 8
      dragHandle?.frame = CGRect(
        x: contentWidth - handleWidth / 2,
        y: 0,
        width: handleWidth,
        height: bounds.height
      )
    } else {
      contentVC.view.frame = bounds
    }
  }

  // MARK: Content management

  func setContent(_ vc: UIViewController) {
    contentVC.willMove(toParent: nil)
    contentVC.view.removeFromSuperview()
    contentVC.removeFromParent()

    contentVC = vc
    installContent(vc)
  }

  private func installContent(_ vc: UIViewController) {
    addChild(vc)
    vc.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    view.addSubview(vc.view)
    vc.didMove(toParent: self)

    // Bring inspector and drag handle in front
    if let container = inspectorContainer {
      view.bringSubviewToFront(container)
    }
    if let handle = dragHandle {
      view.bringSubviewToFront(handle)
    }

    layoutChildren()
  }

  // MARK: Inspector management

  /// The secondary (bottom) VC in the inspector panel, shown below the
  /// primary when lyrics are active.
  private var inspectorSecondaryVC: UIViewController?

  /// Shows the inspector panel with a primary VC (queue) and an optional
  /// secondary VC (lyrics) stacked below it.
  func showInspector(primaryVC: UIViewController, secondaryVC: UIViewController? = nil) {
    hideInspector()

    inspectorVC = primaryVC
    inspectorSecondaryVC = secondaryVC
    addChild(primaryVC)
    if let secondaryVC { addChild(secondaryVC) }

    let container = UIView()
    container.clipsToBounds = true
    container.autoresizingMask = [.flexibleLeftMargin, .flexibleHeight]
    view.addSubview(container)
    inspectorContainer = container

    // Frosted-glass background
    let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
    blur.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    blur.frame = container.bounds
    container.addSubview(blur)

    primaryVC.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    primaryVC.view.backgroundColor = .clear
    container.addSubview(primaryVC.view)
    primaryVC.didMove(toParent: self)

    if let secondaryVC {
      secondaryVC.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
      // Don't override the secondary VC's background — it sets its own
      // (e.g. LyricsVC uses 90% black / 95% white).
      container.addSubview(secondaryVC.view)
      secondaryVC.didMove(toParent: self)

      // Create vertical drag handle between queue (top) and lyrics (bottom)
      let vHandle = UIView()
      vHandle.backgroundColor = .clear
      #if targetEnvironment(macCatalyst)
        vHandle.addInteraction(UIPointerInteraction(delegate: self))
      #endif
      let vPan = UIPanGestureRecognizer(
        target: self, action: #selector(handleVerticalDragGesture(_:))
      )
      vHandle.addGestureRecognizer(vPan)
      container.addSubview(vHandle)
      verticalDragHandle = vHandle
    }

    // Create the horizontal drag handle
    let handle = UIView()
    handle.backgroundColor = .clear
    #if targetEnvironment(macCatalyst)
      handle.addInteraction(UIPointerInteraction(delegate: self))
    #endif
    let pan = UIPanGestureRecognizer(target: self, action: #selector(handleDragGesture(_:)))
    handle.addGestureRecognizer(pan)
    view.addSubview(handle)
    dragHandle = handle

    layoutChildren()
  }

  func hideInspector() {
    guard inspectorVC != nil else { return }

    inspectorVC?.willMove(toParent: nil)
    inspectorVC?.view.removeFromSuperview()
    inspectorVC?.removeFromParent()
    inspectorVC = nil

    inspectorSecondaryVC?.willMove(toParent: nil)
    inspectorSecondaryVC?.view.removeFromSuperview()
    inspectorSecondaryVC?.removeFromParent()
    inspectorSecondaryVC = nil

    verticalDragHandle?.removeFromSuperview()
    verticalDragHandle = nil

    inspectorContainer?.removeFromSuperview()
    inspectorContainer = nil

    dragHandle?.removeFromSuperview()
    dragHandle = nil

    layoutChildren()
  }

  var hasInspector: Bool { inspectorVC != nil }

  // MARK: Drag gesture

  @objc
  private func handleDragGesture(_ gesture: UIPanGestureRecognizer) {
    switch gesture.state {
    case .began:
      dragStartWidth = currentInspectorWidth
    case .changed:
      let translation = gesture.translation(in: view)
      // Dragging left (negative x) increases inspector width
      let newWidth = dragStartWidth - translation.x
      let maxAllowed = view.bounds.width - 200
      currentInspectorWidth = newWidth.clamped(
        to: Self.minInspectorWidth...min(Self.maxInspectorWidth, maxAllowed)
      )
      layoutChildren()
    default:
      break
    }
  }

  @objc
  private func handleVerticalDragGesture(_ gesture: UIPanGestureRecognizer) {
    guard let inspectorContainer else { return }
    switch gesture.state {
    case .began:
      dragStartSplitRatio = inspectorSplitRatio
    case .changed:
      let translation = gesture.translation(in: inspectorContainer)
      let totalHeight = inspectorContainer.bounds.height
      guard totalHeight > 0 else { return }
      let newRatio = dragStartSplitRatio + translation.y / totalHeight
      inspectorSplitRatio = newRatio.clamped(to: Self.minSplitRatio...Self.maxSplitRatio)
      layoutChildren()
    default:
      break
    }
  }
}

// MARK: - SecondaryContainerVC + UIPointerInteractionDelegate

extension SecondaryContainerVC: UIPointerInteractionDelegate {
  func pointerInteraction(
    _ interaction: UIPointerInteraction,
    styleFor region: UIPointerRegion
  ) -> UIPointerStyle? {
    if interaction.view === dragHandle {
      // Horizontal resize cursor for the width drag handle
      return UIPointerStyle(shape: .horizontalBeam(length: 24), constrainedAxes: .vertical)
    } else if interaction.view === verticalDragHandle {
      // Vertical resize cursor for the split drag handle
      return UIPointerStyle(shape: .verticalBeam(length: 24), constrainedAxes: .horizontal)
    }
    return nil
  }
}

// MARK: - Comparable + clamped

private extension Comparable {
  func clamped(to range: ClosedRange<Self>) -> Self {
    min(max(self, range.lowerBound), range.upperBound)
  }
}

// MARK: - SplitVC

class SplitVC: UISplitViewController {
  public static let sidebarWidth: CGFloat = 250
  public static let inspectorWidth: CGFloat = 300

  var miniPlayer: MiniPlayerView?
  var miniPlayerLeadingConstraint: NSLayoutConstraint?
  var miniPlayerTrailingConstraint: NSLayoutConstraint?
  var miniPlayerBottomConstraint: NSLayoutConstraint?
  var miniPlayerHeightConstraint: NSLayoutConstraint?
  var welcomePopupPresenter = WelcomePopupPresenter()
  private let account: Account!

  /// The container that holds main content + optional inspector panel.
  private var secondaryContainer: SecondaryContainerVC!

  init(style: UISplitViewController.Style, account: Account) {
    self.account = account
    super.init(style: style)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    setViewController(
      embeddInNavigation(vc: AppStoryboard.Main.segueToSideBar(account: account)),
      for: .primary
    )

    // Create the secondary container that manages content + inspector
    secondaryContainer = SecondaryContainerVC(contentVC: defaultSecondaryNavVC)
    setViewController(secondaryContainer, for: .secondary)

    primaryEdge = .leading
    primaryBackgroundStyle = .sidebar

    if appDelegate.storage.settings.user.isOfflineMode {
      appDelegate.eventLogger.info(topic: "Reminder", message: "Offline Mode is active.")
    }

    miniPlayer = MiniPlayerView(player: appDelegate.player)
    miniPlayer!.configureForMac()
    guard let miniPlayer else { return }

    displayOrHideInspector()

    let currentInspectorWidth: CGFloat = secondaryContainer.activeInspectorWidth

    view.addSubview(miniPlayer.glassContainer)
    // Set up constraints to pin it to the bottom, left, and right
    miniPlayer.glassContainer.translatesAutoresizingMaskIntoConstraints = false

    miniPlayer.glassContainer.layer.cornerRadius = 25
    miniPlayer.glassContainer.clipsToBounds = true

    miniPlayerLeadingConstraint = miniPlayer.glassContainer.leadingAnchor.constraint(
      equalTo: view.safeAreaLayoutGuide.leadingAnchor,
      constant: primaryColumnWidth + 20
    )
    miniPlayerTrailingConstraint = miniPlayer.glassContainer.trailingAnchor.constraint(
      equalTo: view.safeAreaLayoutGuide.trailingAnchor,
      constant: -currentInspectorWidth - 20
    )
    miniPlayerBottomConstraint = view.safeAreaLayoutGuide.bottomAnchor.constraint(
      equalTo: miniPlayer.glassContainer.bottomAnchor,
      constant: 15.0
    )
    miniPlayerHeightConstraint = miniPlayer.glassContainer.heightAnchor
      .constraint(equalToConstant: 50)

    NSLayoutConstraint.activate([
      miniPlayerLeadingConstraint!,
      miniPlayerTrailingConstraint!,
      miniPlayerBottomConstraint!,
      miniPlayerHeightConstraint!,
    ])
  }

  override func viewWillLayoutSubviews() {
    super.viewWillLayoutSubviews()

    let currentInspectorWidth: CGFloat = secondaryContainer.activeInspectorWidth

    miniPlayerLeadingConstraint?.constant = (isSidebarVisible ? primaryColumnWidth : -0) + 40
    miniPlayerTrailingConstraint?.constant = -currentInspectorWidth - 40
  }

  override func viewIsAppearing(_ animated: Bool) {
    super.viewIsAppearing(animated)

    // set min and max sidebar width
    minimumPrimaryColumnWidth = Self.sidebarWidth
    maximumPrimaryColumnWidth = Self.sidebarWidth
    welcomePopupPresenter.displayInfoPopupsIfNeeded()
    miniPlayer?.refreshPlayer()
  }

  func displayOrHideInspector() {
    // The queue is always displayed in the right panel on macOS.
    // When lyrics are enabled, the panel splits vertically:
    // queue on top, lyrics on bottom.
    let queueVC = QueueVC()
    let lyricsVC: LyricsVC? = appDelegate.storage.settings.user.isPlayerLyricsDisplayed
      ? LyricsVC()
      : nil
    secondaryContainer.showInspector(primaryVC: queueVC, secondaryVC: lyricsVC)
  }

  var isSidebarVisible: Bool {
    switch displayMode {
    case .allVisible, .automatic, .oneBesideSecondary, .primaryOverlay, .twoBesideSecondary,
         .twoDisplaceSecondary:
      // Sidebar is visible in some capacity
      return true
    case .oneOverSecondary, .secondaryOnly, .twoOverSecondary:
      // Sidebar is occupying main space
      return false
    @unknown default:
      return true
    }
  }

  func embeddInNavigation(vc: UIViewController) -> UINavigationController {
    UINavigationController(rootViewController: vc)
  }

  var defaultSecondaryNavVC: UINavigationController {
    embeddInNavigation(vc: TabNavigatorItem.home.getController(account: account))
  }

  public func push(vc: UIViewController) {
    guard let navController = secondaryContainer.contentVC as? UINavigationController else {
      // No navigation controller – replace content with a new one
      secondaryContainer.setContent(embeddInNavigation(vc: vc))
      return
    }

    // Ensure the navigation controller has a root view controller before pushing
    if navController.viewControllers.isEmpty {
      let homeVC = TabNavigatorItem.home.getController(account: account)
      navController.setViewControllers([homeVC, vc], animated: false)
    } else {
      navController.pushViewController(vc, animated: false)
    }
  }
}

// MARK: MainSceneHostingViewController

extension SplitVC: MainSceneHostingViewController {
  public func pushNavLibrary(vc: UIViewController) {
    push(vc: vc)
  }

  public func pushLibraryCategory(vc: UIViewController) {
    secondaryContainer.setContent(embeddInNavigation(vc: vc))
  }

  func pushTabCategory(tabCategory: TabNavigatorItem) {
    let vc = tabCategory.getController(account: account)
    secondaryContainer.setContent(embeddInNavigation(vc: vc))
  }

  func displaySearch() {
    visualizePopupPlayer(direction: .close, animated: true) {
      let searchVC = AppStoryboard.Main.segueToSearch(account: self.account)
      self.secondaryContainer.setContent(self.embeddInNavigation(vc: searchVC))
      Task {
        try await Task.sleep(nanoseconds: 500_000_000)
        searchVC.activateSearchBar()
      }
    }
  }

  func getSafeAreaExtension() -> CGFloat {
    guard let miniPlayerBottomConstraint,
          let miniPlayerHeightConstraint else { return 0.0 }

    return miniPlayerBottomConstraint.constant + miniPlayerHeightConstraint.constant
  }
}
