/*
 * TNWindowAddContact.j
 *
 * Copyright (C) 2010 Antoine Mercadal <antoine.mercadal@inframonde.eu>
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as
 * published by the Free Software Foundation, either version 3 of the
 * License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Affero General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

@import <Foundation/Foundation.j>

@import <AppKit/CPButton.j>
@import <AppKit/CPButton.j>
@import <AppKit/CPTextField.j>
@import <AppKit/CPWindow.j>

@import <TNKit/TNAlert.j>

@import <GrowlCappuccino/GrowlCappuccino.j>
@import <StropheCappuccino/PubSub/TNPubSubController.j>
@import <StropheCappuccino/TNStropheIMClient.j>

@import "TNPermissionsCenter.j"

@class CPLocalizedString
@global TNArchipelEntityTypeUser
@global TNArchipelEntityTypeVirtualMachine
@global TNArchipelEntityTypeHypervisor

/*! @ingroup archipelcore
    subclass of CPWindow that allows to add a TNStropheContact
*/
@implementation TNContactsController: CPObject
{
    @outlet CPButton        buttonAdd;
    @outlet CPButton        buttonCancel;
    @outlet CPPopover       mainPopover;
    @outlet CPTextField     newContactJID;
    @outlet CPTextField     newContactName;

    TNPubSubController      _pubsubController   @accessors(property=pubSubController);

    CPDictionary            _localAvatars;
}

#pragma mark -
#pragma mark Initialization

- (void)awakeFromCib
{
    _localAvatars = [CPDictionary dictionary];

    var bundle = [CPBundle mainBundle];

    [_localAvatars setObject:CPImageInBundle(@"Avatars/RemoteAvatars/defaultvm.png", nil, bundle) forKey:@"vm"];
    [_localAvatars setObject:CPImageInBundle(@"Avatars/RemoteAvatars/defaulthypervisor.png", nil, bundle) forKey:@"hypervisor"];

    [[CPNotificationCenter defaultCenter] addObserver:self selector:@selector(_performPushRosterAdded:) name:TNStropheRosterPushAddedContactNotification object:nil];
    [[CPNotificationCenter defaultCenter] addObserver:self selector:@selector(_performPushRosterRemoved:) name:TNStropheRosterPushRemovedContactNotification object:nil];
    [[CPNotificationCenter defaultCenter] addObserver:self selector:@selector(_performPushRosterUpdated:) name:TNStropheRosterPushUpdatedContactNotification object:nil];
    [[CPNotificationCenter defaultCenter] addObserver:self selector:@selector(_didRecieveContactVCard:) name:TNStropheContactVCardReceivedNotification object:nil];
}

#pragma mark -
#pragma mark Utilities

- (void)subscribeToPubSubNodeOfContactWithJID:(TNStropheJID)aJID
{
    var roster = [[TNStropheIMClient defaultClient] roster];
    if ([roster analyseVCard:[[roster contactWithJID:aJID] vCard]] == TNArchipelEntityTypeUser)
        return;

    var nodeName = @"/archipel/" + [aJID bare] + @"/events",
        server = [TNStropheJID stropheJIDWithString:@"pubsub." + [aJID domain]];

    if (![_pubsubController nodeWithName:nodeName])
        [_pubsubController subscribeToNodeWithName:nodeName server:server];
}

- (void)unsubscribeToPubSubNodeOfContactWithJID:(TNStropheJID)aJID
{
    var roster = [[TNStropheIMClient defaultClient] roster];
    if ([roster analyseVCard:[[roster contactWithJID:aJID] vCard]] == TNArchipelEntityTypeUser)
        return;

    var nodeName = "/archipel/" + [aJID bare] + "/events",
        server = [TNStropheJID stropheJIDWithString:@"pubsub." + [aJID domain]];

    if ([_pubsubController nodeWithName:nodeName])
        [_pubsubController unsubscribeFromNodeWithName:nodeName server:server]
}

- (void)addContact
{
    var name = [newContactName stringValue],
        JID;

    try
    {
          JID = [TNStropheJID stropheJIDWithString:[newContactJID stringValue]]
    }
    catch (e)
    {
        JID = nil;
    }

    if (![JID node] || ![JID domain] || [JID resource])
    {
        [TNAlert showAlertWithMessage:CPLocalizedString(@"JID is not valid", @"JID is not valid")
                          informative:CPLocalizedString(@"You must enter a JID using the form user@domain.", @"You must enter a JID using the form user@domain.")
                                style:CPCriticalAlertStyle];
        return;
    }
    [[[TNStropheIMClient defaultClient] roster] addContact:JID withName:name inGroupWithPath:nil];

    [mainPopover close];

    CPLog.info(@"added contact " + JID);

    [[TNGrowlCenter defaultCenter] pushNotificationWithTitle:CPLocalizedString(@"Contact", @"Contact")
                                                     message:CPLocalizedString(@"Contact ", @"Contact ") + JID + CPLocalizedString(@" has been added",  @" has been added")];

}

/*! delete a contact
    @param aContact the contact to delete
*/
- (void)deleteContact:(TNStropheContact)aContact
{
    [self unsubscribeToPubSubNodeOfContactWithJID:[aContact JID]];
    [[TNPermissionsCenter defaultCenter] uncachePermissionsForEntity:aContact];

    [[[TNStropheIMClient defaultClient] roster] removeContact:aContact];

    CPLog.info(@"contact " + [aContact JID] + "removed");
    [[TNGrowlCenter defaultCenter] pushNotificationWithTitle:CPLocalizedString(@"Contact", @"Contact")
                                                     message:CPLocalizedString(@"Contact ", @"Contact ") + [aContact JID] + CPLocalizedString(@" has been removed", @" has been removed")];
}

/*! ask contact for subscription
    @param aJID the target JID
*/
- (void)askSubscription:(id)aJID
{
    [[[TNStropheIMClient defaultClient] roster] askAuthorizationTo:aJID];
    [[[TNStropheIMClient defaultClient] roster] authorizeJID:aJID];
}

/*! remove subscription
    @param aJID the target JID
*/
- (void)removeSubscription:(id)aJID
{
    [[[TNStropheIMClient defaultClient] roster] askAuthorizationTo:aJID];
    [[[TNStropheIMClient defaultClient] roster] unauthorizeJID:aJID];
}


#pragma mark -
#pragma mark Notification handlers

- (void)_didPubSubSubscriptionsRetrieved:(CPNotification)aNotification
{
    var eventNode = [[[aNotification object] nodes] objectAtIndex:0];

    [[CPNotificationCenter defaultCenter] removeObserver:self name:TNStrophePubSubSubscriptionsRetrievedNotification object:[aNotification object]];

    [eventNode unsubscribe];
}

- (void)_didRecieveContactVCard:(CPNotification)aNotification
{
    var contact = [aNotification object];

    [self subscribeToPubSubNodeOfContactWithJID:[contact JID]];
}

- (void)_performPushRosterAdded:(CPNotification)aNotification
{
    var theJID = [aNotification userInfo];

    [self askSubscription:theJID];
}

- (void)_performPushRosterRemoved:(CPNotification)aNotification
{
    var theJID = [aNotification userInfo];

    [self unsubscribeToPubSubNodeOfContactWithJID:theJID];
}

- (void)_performPushRosterUpdated:(CPNotification)aNotification
{
    var theJID = [aNotification userInfo];

    [self subscribeToPubSubNodeOfContactWithJID:theJID];
}


#pragma mark -
#pragma mark Actions

/*! overide of the orderFront
    @param aSender the sender
*/
- (IBAction)showWindow:(id)aSender
{
    [newContactJID setStringValue:@""];
    [newContactName setStringValue:@""];

    [mainPopover showRelativeToRect:nil ofView:aSender preferredEdge:nil];
    [mainPopover setDefaultButton:buttonAdd];
    [mainPopover makeFirstResponder:newContactJID];
}

/*! close the main window
    @param aSender the sender
*/
- (IBAction)closeWindow:(id)aSender
{
    [mainPopover close];
}

/*! add a contact according to the values of the outlets
    @param aSender the sender
*/
- (IBAction)addContact:(id)aSender
{
    [self addContact];
}

/*! action sent by alert to show help for subscription
    @param aSender the sender of the action
*/
- (IBAction)showHelpForSubscription:(id)aSender
{
    window.open("http://www.google.fr/search?q=XMPP subscription request", "_new");
}

/*! action sent by alert to show help for subscription
    @param aSender the sender of the action
*/
- (IBAction)showHelpForDelete:(id)aSender
{
    window.open("http://www.google.fr/search?q=XMPP delete contact", "_new");
}

#pragma mark -
#pragma mark Delegate

/*! Delegate method of main TNStropheRoster.
    will be performed when a subscription request is sent
    @param requestStanza TNStropheStanza cotainining the subscription request
*/
- (void)roster:(TNStropheRoster)aRoster receiveSubscriptionRequest:(id)requestStanza
{
    var nick;

    if ([requestStanza firstChildWithName:@"nick"])
        nick = [[requestStanza firstChildWithName:@"nick"] text];
    else
        nick = [requestStanza from];

    var alert = [TNAlert alertWithMessage:CPLocalizedString(@"Subscription request", @"Subscription request")
                              informative:nick + CPLocalizedString(@" is asking you subscription. Do you want to authorize it ?", @" is asking you subscription. Do you want to authorize it ?")
                                   target:self
                                  actions:[[CPLocalizedString("Accept", "Accept"), @selector(performAuthorize:)],
                                            [CPLocalizedString("Decline", "Decline"), @selector(performRefuse:)]]];

    [alert setHelpTarget:self action:@selector(showHelpForSubscription:)];
    [alert setUserInfo:requestStanza]
    [alert runModal];
}

/*! Action of didReceiveSubscriptionRequest's confirmation alert.
    Will accept the subscription and try to register to Archipel pubsub nodes
*/
- (void)performAuthorize:(TNStropheStanza)aRequestStanza
{
    [[[TNStropheIMClient defaultClient] roster] answerAuthorizationRequest:aRequestStanza answer:YES];
}

/*! Action of didReceiveSubscriptionRequest's confirmation alert.
    Will refuse the subscription and try to unregister to Archipel pubsub nodes
*/
- (void)performRefuse:(TNStropheStanza)aRequestStanza
{
    [[[TNStropheIMClient defaultClient] roster] answerAuthorizationRequest:aRequestStanza answer:NO];
}

/*! TNRoster Delegate
*/
- (CPImage)avatarForContact:(TNStropheContact)aContact
{
    var entityType = [[[TNStropheIMClient defaultClient] roster] analyseVCard:[aContact vCard]];

    switch (entityType)
    {
        case TNArchipelEntityTypeVirtualMachine:
            return [_localAvatars objectForKey:@"vm"];
            break;
        case TNArchipelEntityTypeHypervisor:
            return [_localAvatars objectForKey:@"hypervisor"];
            break;
        default:
            return nil;
    }
}

@end
