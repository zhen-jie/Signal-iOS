//
//  Copyright (c) 2020 Open Whisper Systems. All rights reserved.
//

import Foundation
import UIKit
import PromiseKit

@objc
public class GroupMigrationActionSheet: UIView {

    enum Mode {
        case upgradeGroup(migrationInfo: GroupsV2MigrationInfo)
        case tooManyMembers
        case someMembersCantMigrate
        case migrationComplete
        case reAddDroppedMembers(members: Set<SignalServiceAddress>)
    }

    private let groupThread: TSGroupThread
    private let mode: Mode

    weak var actionSheetController: ActionSheetController?

    private let stackView = UIStackView()

    required init(groupThread: TSGroupThread, mode: Mode) {
        self.groupThread = groupThread
        self.mode = mode

        super.init(frame: .zero)

        configure()
    }

    @objc
    public static func actionSheetForMigratedGroup(groupThread: TSGroupThread) -> GroupMigrationActionSheet {
        let droppedMembers = groupThread.groupModel.getDroppedMembers
        if droppedMembers.isEmpty {
            return GroupMigrationActionSheet(groupThread: groupThread,
                                             mode: .migrationComplete)
        } else {
            return GroupMigrationActionSheet(groupThread: groupThread,
                                             mode: .reAddDroppedMembers(members: Set(droppedMembers)))
        }
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc
    public func present(fromViewController: UIViewController) {
        let actionSheetController = ActionSheetController()
        actionSheetController.customHeader = self
        actionSheetController.isCancelable = true
        fromViewController.presentActionSheet(actionSheetController)
        self.actionSheetController = actionSheetController
    }

    @objc
    public func configure() {
        let subviews = buildContents()

        let stackView = UIStackView(arrangedSubviews: subviews)
        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.layoutMargins = UIEdgeInsets(top: 48, leading: 20, bottom: 38, trailing: 24)
        stackView.isLayoutMarginsRelativeArrangement = true
        stackView.addBackgroundView(withBackgroundColor: Theme.backgroundColor)

        layoutMargins = .zero
        addSubview(stackView)
        stackView.autoPinEdgesToSuperviewMargins()
        stackView.setContentHuggingHorizontalLow()
    }

    private struct Builder {

        // MARK: - Dependencies

        private static var contactsManager: OWSContactsManager {
            return Environment.shared.contactsManager
        }

        // MARK: -

        var subviews = [UIView]()

        func buildLabel() -> UILabel {
            let label = UILabel()
            label.textColor = Theme.primaryTextColor
            label.numberOfLines = 0
            label.lineBreakMode = .byWordWrapping
            return label
        }

        func buildTitleLabel(text: String) -> UILabel {
            let label = UILabel()
            label.text = text
            label.textColor = Theme.primaryTextColor
            label.font = UIFont.ows_dynamicTypeTitle2.ows_semibold
            label.numberOfLines = 0
            label.lineBreakMode = .byWordWrapping
            label.textAlignment = .center
            return label
        }

        mutating func addTitleLabel(text: String) {
            subviews.append(buildTitleLabel(text: text))
        }

        mutating func addVerticalSpacer(height: CGFloat) {
            subviews.append(UIView.spacer(withHeight: height))
        }

        mutating func addRow(subview: UIView, hasBulletPoint: Bool) {

            let bulletSize = CGSize(width: 5, height: 11)
            let bulletWrapper = UIView.container()
            bulletWrapper.autoSetDimension(.width, toSize: bulletSize.width)
            bulletWrapper.setContentHuggingHorizontalHigh()
            bulletWrapper.setCompressionResistanceHorizontalHigh()

            if hasBulletPoint {
                let bullet = UIView()
                bullet.autoSetDimensions(to: bulletSize)
                // TODO: Dark theme value?
                bullet.backgroundColor =  UIColor(rgbHex: 0xdedede)
                bulletWrapper.addSubview(bullet)
                bullet.autoPinEdge(toSuperviewEdge: .top, withInset: 4)
                bullet.autoPinEdge(toSuperviewEdge: .leading)
                bullet.autoPinEdge(toSuperviewEdge: .trailing)
                bullet.setContentHuggingHigh()
                bullet.setCompressionResistanceHigh()
            }

            subview.setContentHuggingHorizontalLow()
            subview.setCompressionResistanceHigh()

            let row = UIStackView(arrangedSubviews: [bulletWrapper, subview])
            row.axis = .horizontal
            row.alignment = .top
            row.spacing = 20
            row.setCompressionResistanceVerticalHigh()
            row.setContentHuggingHorizontalLow()
            subviews.append(row)
        }

        mutating func addBodyLabel(_ text: String) {
            let label = buildLabel()
            label.font = .ows_dynamicTypeBody
            label.text = text
            addRow(subview: label, hasBulletPoint: true)
        }

        mutating func addMemberRow(address: SignalServiceAddress,
                          transaction: SDSAnyReadTransaction) {

            let avatarSize: UInt = 28
            let conversationColorName = TSContactThread.conversationColorName(forContactAddress: address,
                                                                              transaction: transaction)
            let avatarBuilder = OWSContactAvatarBuilder(address: address,
                                                        colorName: conversationColorName,
                                                        diameter: avatarSize,
                                                        transaction: transaction)
            let avatar = avatarBuilder.build(with: transaction)

            let avatarView = AvatarImageView()
            avatarView.image = avatar
            avatarView.autoSetDimensions(to: CGSize(square: CGFloat(avatarSize)))
            avatarView.setContentHuggingHorizontalHigh()

            let label = buildLabel()
            label.font = .ows_dynamicTypeBody
            label.text = Self.contactsManager.displayName(for: address, transaction: transaction)
            label.setContentHuggingHorizontalLow()

            let row = UIStackView(arrangedSubviews: [avatarView, label])
            row.axis = .horizontal
            row.alignment = .center
            row.spacing = 6
            row.setContentHuggingHorizontalLow()

            addRow(subview: row, hasBulletPoint: false)
        }

        mutating func addBottomButton(title: String,
                                      titleColor: UIColor,
                                      backgroundColor: UIColor,
                                      target: Any,
                                      selector: Selector) {
            let buttonFont = UIFont.ows_dynamicTypeBodyClamped.ows_semibold
            let buttonHeight = OWSFlatButton.heightForFont(buttonFont)
            let upgradeButton = OWSFlatButton.button(title: title,
                                                     font: buttonFont,
                                                     titleColor: titleColor,
                                                     backgroundColor: backgroundColor,
                                                     target: target,
                                                     selector: selector)
            upgradeButton.autoSetDimension(.height, toSize: buttonHeight)
            subviews.append(upgradeButton)
        }

        mutating func addOkayButton(target: Any, selector: Selector) {
            addBottomButton(title: CommonStrings.okayButton,
                            titleColor: .white,
                            backgroundColor: .ows_accentBlue,
                            target: target,
                            selector: selector)
        }
    }

    private func buildContents() -> [UIView] {
        switch mode {
        case .upgradeGroup(let migrationInfo):
            return buildUpgradeGroupContents(migrationInfo: migrationInfo)
        case .tooManyMembers:
            return buildTooManyMembersContents()
        case .someMembersCantMigrate:
            return buildSomeMembersCantMigrateContents()
        case .migrationComplete:
            return buildMigrationCompleteContents()
        case .reAddDroppedMembers(let members):
            return buildReAddDroppedMembersContents(members: members)
        }
    }

    private func buildUpgradeGroupContents(migrationInfo: GroupsV2MigrationInfo) -> [UIView] {
        var builder = Builder()

        builder.addTitleLabel(text: NSLocalizedString("GROUPS_LEGACY_GROUP_UPGRADE_ALERT_TITLE",
                                                      comment: "Title for the 'upgrade legacy group' alert view."))
        builder.addVerticalSpacer(height: 28)

        builder.addBodyLabel(NSLocalizedString("GROUPS_LEGACY_GROUP_NEW_GROUP_DESCRIPTION",
                                               comment: "Explanation of new groups in the 'legacy group' alert views."))
        builder.addVerticalSpacer(height: 20)
        builder.addBodyLabel(NSLocalizedString("GROUPS_LEGACY_GROUP_UPGRADE_ALERT_SECTION_2_BODY",
                                               comment: "Body text for the second section of the 'upgrade legacy group' alert view."))

        databaseStorage.read { transaction in
            // TODO: We need to break these out into separate sections.
            // TODO: Scroll view?
            //            let members = (migrationInfo.membersWithoutUuids +
            //                migrationInfo.membersWithoutCapabilities +
            //                migrationInfo.membersWithoutProfileKeys)
            var members = (migrationInfo.membersWithoutUuids +
                migrationInfo.membersWithoutCapabilities +
                migrationInfo.membersWithoutProfileKeys)
            // TODO: Remove.
//            members = members + members
//            members = members + members
//            members = members + members
//            members = members + members
            if !members.isEmpty {
                builder.addVerticalSpacer(height: 20)
                builder.addBodyLabel(NSLocalizedString("GROUPS_LEGACY_GROUP_UPGRADE_ALERT_SECTION_INVITED_MEMBERS",
                                                       comment: "Body text for the 'invites members' section of the 'upgrade legacy group' alert view."))
                for address in members {
                    builder.addVerticalSpacer(height: 16)
                    builder.addMemberRow(address: address, transaction: transaction)
                }
            }
        }

        builder.addVerticalSpacer(height: 40)

        builder.addBottomButton(title: NSLocalizedString("GROUPS_LEGACY_GROUP_UPGRADE_ALERT_UPGRADE_BUTTON",
                                                         comment: "Label for the 'upgrade this group' button in the 'upgrade legacy group' alert view."),
                                titleColor: .white,
                                backgroundColor: .ows_accentBlue,
                                target: self,
                                selector: #selector(upgradeGroup))
        builder.addVerticalSpacer(height: 5)
        builder.addBottomButton(title: CommonStrings.cancelButton,
                                titleColor: .ows_accentBlue,
                                backgroundColor: .white,
                                target: self,
                                selector: #selector(dismissAlert))

        return builder.subviews
    }

    private func buildTooManyMembersContents() -> [UIView] {
        var builder = Builder()

        builder.addTitleLabel(text: NSLocalizedString("GROUPS_LEGACY_GROUP_CANT_UPGRADE_ALERT_TITLE",
                                                      comment: "Title for the 'can't upgrade legacy group' alert view."))
        builder.addVerticalSpacer(height: 28)

        builder.addBodyLabel(NSLocalizedString("GROUPS_LEGACY_GROUP_NEW_GROUP_DESCRIPTION",
                                               comment: "Explanation of new groups in the 'legacy group' alert views."))
        builder.addVerticalSpacer(height: 20)
        let descriptionFormat = NSLocalizedString("GROUPS_LEGACY_GROUP_CANT_UPGRADE_ALERT_TOO_MANY_MEMBERS_FORMAT",
                                                  comment: "Text indicating that a legacy group can't be upgraded because it has too many members. Embeds {{ The maximum number of members allowed in a group. }}.")
        let maxMemberCount = OWSFormat.formatUInt(RemoteConfig.groupsV2MaxGroupSizeHardLimit - 1)
        let description = String(format: descriptionFormat, maxMemberCount)
        builder.addBodyLabel(description)

        builder.addVerticalSpacer(height: 100)

        builder.addOkayButton(target: self, selector: #selector(dismissAlert))

        return builder.subviews
    }

    private func buildSomeMembersCantMigrateContents() -> [UIView] {
        var builder = Builder()

        builder.addTitleLabel(text: NSLocalizedString("GROUPS_LEGACY_GROUP_NEW_GROUPS_ALERT_TITLE",
                                                      comment: "Title for the 'new groups' alert view."))
        builder.addVerticalSpacer(height: 28)

        builder.addBodyLabel(NSLocalizedString("GROUPS_LEGACY_GROUP_NEW_GROUP_DESCRIPTION",
                                               comment: "Explanation of new groups in the 'legacy group' alert views."))
        builder.addVerticalSpacer(height: 20)
        builder.addBodyLabel(NSLocalizedString("GROUPS_LEGACY_GROUP_CANT_UPGRADE_YET_1",
                                               comment: "Explanation of group migration for groups that can't yet be migrated in the 'legacy group' alert views."))
        builder.addVerticalSpacer(height: 20)
        builder.addBodyLabel(NSLocalizedString("GROUPS_LEGACY_GROUP_CANT_UPGRADE_YET_2",
                                               comment: "Explanation of group migration for groups that can't yet be migrated in the 'legacy group' alert views."))

        builder.addVerticalSpacer(height: 100)

        builder.addOkayButton(target: self, selector: #selector(dismissAlert))

        return builder.subviews
    }

    private func buildMigrationCompleteContents() -> [UIView] {
        var builder = Builder()

        builder.addTitleLabel(text: NSLocalizedString("GROUPS_LEGACY_GROUP_MIGRATED_GROUP_ALERT_TITLE",
                                                      comment: "Title for the 'migrated group' alert view."))
        builder.addVerticalSpacer(height: 28)

        builder.addBodyLabel(NSLocalizedString("GROUPS_LEGACY_GROUP_NEW_GROUP_DESCRIPTION",
                                               comment: "Explanation of new groups in the 'legacy group' alert views."))
        builder.addVerticalSpacer(height: 20)
        builder.addBodyLabel(NSLocalizedString("GROUPS_LEGACY_GROUP_MIGRATED_GROUP_DESCRIPTION",
                                               comment: "Explanation of group migration for a migrated group in the 'legacy group' alert views."))

        builder.addVerticalSpacer(height: 100)

        builder.addOkayButton(target: self, selector: #selector(dismissAlert))

        return builder.subviews
    }

    private func buildReAddDroppedMembersContents(members: Set<SignalServiceAddress>) -> [UIView] {
        var builder = Builder()

        if members.count > 1 {
            builder.addTitleLabel(text: NSLocalizedString("GROUPS_LEGACY_GROUP_RE_ADD_DROPPED_GROUP_MEMBERS_ALERT_TITLE_N",
                                                          comment: "Title for the 're-add dropped group members' alert view."))
            builder.addVerticalSpacer(height: 28)
            builder.addBodyLabel(NSLocalizedString("GROUPS_LEGACY_GROUP_RE_ADD_DROPPED_GROUP_MEMBERS_DESCRIPTION_N",
                                                   comment: "Explanation of 're-adding dropped group member' in the 'legacy group' alert views."))
        } else {
            builder.addTitleLabel(text: NSLocalizedString("GROUPS_LEGACY_GROUP_RE_ADD_DROPPED_GROUP_MEMBERS_ALERT_TITLE_1",
                                                          comment: "Title for the 're-add dropped group members' alert view."))
            builder.addVerticalSpacer(height: 28)
            builder.addBodyLabel(NSLocalizedString("GROUPS_LEGACY_GROUP_RE_ADD_DROPPED_GROUP_MEMBERS_DESCRIPTION_1",
                                                   comment: "Explanation of 're-adding dropped group member' in the 'legacy group' alert views."))
        }

        databaseStorage.read { transaction in
            for address in members {
                builder.addVerticalSpacer(height: 16)
                builder.addMemberRow(address: address, transaction: transaction)
            }
        }

        builder.addVerticalSpacer(height: 16)

        builder.addBottomButton(title: NSLocalizedString("GROUPS_LEGACY_GROUP_RE_ADD_DROPPED_GROUP_MEMBERS_ADD_MEMBERS_BUTTON",
                                                         comment: "Label for the 'add members' button in the 're-add dropped group members' alert view."),
                                titleColor: .white,
                                backgroundColor: .ows_accentBlue,
                                target: self,
                                selector: #selector(reAddDroppedMembers))
        builder.addVerticalSpacer(height: 5)
        builder.addBottomButton(title: CommonStrings.cancelButton,
                                titleColor: .ows_accentBlue,
                                backgroundColor: .white,
                                target: self,
                                selector: #selector(dismissAlert))

        return builder.subviews
    }

    private func showToast(text: String) {
        guard let viewController = UIApplication.shared.frontmostViewController else {
            owsFailDebug("Missing frontmostViewController.")
            return
        }

        let toastController = ToastController(text: text)
        let toastInset = viewController.bottomLayoutGuide.length + 8
        toastController.presentToastView(fromBottomOfView: viewController.view, inset: toastInset)
    }

    // MARK: - Events

    @objc
    func dismissAlert() {
        actionSheetController?.dismiss(animated: true)
    }
}

// MARK: -

private extension GroupMigrationActionSheet {

    @objc
    func upgradeGroup() {
        guard let actionSheetController = actionSheetController else {
            owsFailDebug("Missing actionSheetController.")
            return
        }
        ModalActivityIndicatorViewController.present(fromViewController: actionSheetController,
                                                     canCancel: false) { modalActivityIndicator in
                                                        firstly {
                                                            self.upgradePromise()
                                                        }.done { (_) in
                                                            modalActivityIndicator.dismiss {
                                                                self.dismissAndShowUpgradeSuccessToast()
                                                            }
                                                        }.catch { error in
                                                            owsFailDebug("Error: \(error)")

                                                            modalActivityIndicator.dismiss {
                                                                self.showUpgradeFailedAlert(error: error)
                                                            }
                                                        }
        }
    }

    private func upgradePromise() -> Promise<Void> {
        GroupsV2Migration.tryManualMigration(groupThread: groupThread).asVoid()
    }

    private func dismissAndShowUpgradeSuccessToast() {
        AssertIsOnMainThread()

        guard let actionSheetController = actionSheetController else {
            owsFailDebug("Missing actionSheetController.")
            return
        }

        actionSheetController.dismiss(animated: true) {
            self.showUpgradeSuccessToast()
        }
    }

    private func showUpgradeSuccessToast() {
        let text = NSLocalizedString("GROUPS_LEGACY_GROUP_UPGRADE_ALERT_UPGRADE_SUCCEEDED",
                                     comment: "Message indicating the group update succeeded.")
        showToast(text: text)
    }

    private func showUpgradeFailedAlert(error: Error) {
        AssertIsOnMainThread()

        guard let actionSheetController = actionSheetController else {
            owsFailDebug("Missing actionSheetController.")
            return
        }

        let title: String
        // TODO: We need final copy.
        title = NSLocalizedString("GROUPS_LEGACY_GROUP_UPGRADE_ALERT_UPGRADE_FAILED_ERROR",
                                  comment: "Error indicating the group update failed.")
        OWSActionSheets.showActionSheet(title: title, fromViewController: actionSheetController)
    }
}

// MARK: -

private extension GroupMigrationActionSheet {

    @objc
    func reAddDroppedMembers() {
        guard case .reAddDroppedMembers(let members) = mode else {
            owsFailDebug("Invalid mode.")
            return
        }
        guard let actionSheetController = actionSheetController else {
            owsFailDebug("Missing actionSheetController.")
            return
        }
        ModalActivityIndicatorViewController.present(fromViewController: actionSheetController,
                                                     canCancel: false) { modalActivityIndicator in
                                                        firstly {
                                                            self.reAddDroppedMembersPromise(members: members)
                                                        }.done { (_) in
                                                            modalActivityIndicator.dismiss {
                                                                self.dismissAndShowReAddDroppedMembersSuccessToast()
                                                            }
                                                        }.catch { error in
                                                            owsFailDebug("Error: \(error)")

                                                            modalActivityIndicator.dismiss {
                                                                self.showReAddDroppedMembersFailedAlert(error: error)
                                                            }
                                                        }
        }
    }

    private func reAddDroppedMembersPromise(members: Set<SignalServiceAddress>) -> Promise<Void> {
        guard let localAddress = tsAccountManager.localAddress else {
            return Promise(error: OWSAssertionError("Missing localAddress."))
        }
        guard let oldGroupModel = self.groupThread.groupModel as? TSGroupModelV2 else {
            return Promise(error: OWSAssertionError("Invalid groupModel."))
        }

        return firstly { () -> Promise<Void> in
            GroupManager.messageProcessingPromise(for: oldGroupModel,
                                                  description: self.logTag)
        }.map(on: .global()) { (_) in
            let oldGroupMembership = oldGroupModel.groupMembership
            var membershipBuilder = oldGroupMembership.asBuilder
            // We don't need to sort out full and invited members;
            // GroupManager will take care of that.
            var addedCount = 0
            for address in members {
                guard !oldGroupMembership.allMembersOfAnyKind.contains(address) else {
                    continue
                }
                membershipBuilder.addFullMember(address, role: .normal)
                addedCount += 1
            }
            guard addedCount > 0 else {
                throw OWSAssertionError("No members to add.")
            }
            var groupModelBuilder = oldGroupModel.asBuilder
            groupModelBuilder.groupMembership = membershipBuilder.build()
            let newGroupModel = try Self.databaseStorage.read { transaction in
                try groupModelBuilder.buildAsV2(transaction: transaction)
            }
            return newGroupModel
        }.then(on: .global()) { (newGroupModel) in
            // dmConfiguration: nil means don't change disappearing messages configuration.
            GroupManager.localUpdateExistingGroup(oldGroupModel: oldGroupModel,
                                                  newGroupModel: newGroupModel,
                                                  dmConfiguration: nil,
                                                  groupUpdateSourceAddress: localAddress)
        }.asVoid()
    }

    private func dismissAndShowReAddDroppedMembersSuccessToast() {
        AssertIsOnMainThread()

        guard let actionSheetController = actionSheetController else {
            owsFailDebug("Missing actionSheetController.")
            return
        }

        actionSheetController.dismiss(animated: true) {
            self.showReAddDroppedMembersSuccessToast()
        }
    }

    private func showReAddDroppedMembersSuccessToast() {
        // TODO: we need final copy.
        let text = NSLocalizedString("GROUPS_LEGACY_GROUP_RE_ADD_DROPPED_MEMBERS_SUCCEEDED",
                                     comment: "Message indicating the dropped group members were successfully re-added to the group succeeded.")
        showToast(text: text)
    }

    private func showReAddDroppedMembersFailedAlert(error: Error) {
        AssertIsOnMainThread()

        guard let actionSheetController = actionSheetController else {
            owsFailDebug("Missing actionSheetController.")
            return
        }

        let title: String
        // TODO: We need final copy.
        title = NSLocalizedString("GROUPS_LEGACY_GROUP_UPGRADE_ALERT_UPGRADE_FAILED_ERROR",
                                  comment: "Error indicating the group update failed.")
        OWSActionSheets.showActionSheet(title: title, fromViewController: actionSheetController)
    }
}
