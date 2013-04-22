# -*- coding: utf-8 -*-
#
# xmppserver.py
#
# Copyright (C) 2010 Antoine Mercadal <antoine.mercadal@inframonde.eu>
# This file is part of ArchipelProject
# http://archipelproject.org
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

import xmlrpclib
import xmpp

from archipelcore.utils import build_error_iq
from xmppserver_base import TNXMPPServerControllerBase

class TNXMPPServerController (TNXMPPServerControllerBase):

    def __init__(self, configuration, entity, entry_point_group):
        """
        Initialize the plugin.
        @type configuration: Configuration object
        @param configuration: the configuration
        @type entity: L{TNArchipelEntity}
        @param entity: the entity that owns the plugin
        @type entry_point_group: string
        @param entry_point_group: the group name of plugin entry_point
        """
        TNXMPPServerControllerBase.__init__(self, configuration=configuration, entity=entity, entry_point_group=entry_point_group)
        self.xmpp_server        = entity.jid.getDomain()
        self.xmlrpc_host        = self.configuration.get("XMPPSERVER", "xmlrpc_host")
        self.xmlrpc_port        = self.configuration.getint("XMPPSERVER", "xmlrpc_port")
        self.xmlrpc_user        = self.configuration.get("XMPPSERVER", "xmlrpc_user")
        self.xmlrpc_password    = self.configuration.get("XMPPSERVER", "xmlrpc_password")
        self.xmlrpc_prefix       = "https" if self.configuration.getboolean("XMPPSERVER","xmlrpc_sslonly") else "http"
        self.xmlrpc_call        = "%s://%s:%s@%s:%s/" % (self.xmlrpc_prefix, self.xmlrpc_user, self.xmlrpc_password, self.xmlrpc_host, self.xmlrpc_port)
        self.xmlrpc_server      = xmlrpclib.ServerProxy(self.xmlrpc_call)
        self.entity.log.info("XMPPSERVER: Module is using XMLRPC API for managing XMPP server")


    def _send_xmlrpc_call(self, method, args):
        """
        Sends the xml rpc call with given args
        @type method: function
        @param method: the xmlrpc method to launch
        @type args: dict
        @param args: containing the xmlrpc call arguments
        @rtype: dict
        @return: the xmlrpc reply
        """
        try:
            return method(args)
        except Exception as ex:
            raise Exception(str(ex).replace(self.xmlrpc_password, "[PASSWORD_HIDDEN]"))

    ## TNXMPPServerControllerBase implementation


    def group_create(self, ID, name, description):
        """
        Create a new shared roster group
        @type ID: string
        @param ID: the ID of the group
        @type name: string
        @param name: the name of the group
        @type description: string
        @param description: the description of the group
        """
        server = self.entity.jid.getDomain()
        answer = self._send_xmlrpc_call(self.xmlrpc_server.srg_create, {"host": server, "display": ID, "name": name, "description": description, "group": ID})
        if not answer['res'] == 0:
            raise Exception("Cannot create shared roster group. %s" % str(answer))
        self.entity.log.info("XMPPSERVER: Creating a new shared group %s" % ID)
        self.entity.push_change("xmppserver:groups", "created")
        return True

    def group_delete(self, ID):
        """
        Destroy a shared roster group
        @type ID: string
        @param ID: the ID of the group to delete
        """
        server = self.entity.jid.getDomain()
        answer = self._send_xmlrpc_call(self.xmlrpc_server.srg_delete, {"host": server, "group": ID})
        if not answer['res'] == 0:
            raise Exception("Cannot create shared roster group. %s" % str(answer))
        self.entity.log.info("XMPPSERVER: Removing a shared group %s" % ID)
        self.entity.push_change("xmppserver:groups", "deleted")

    def group_list(self):
        """
        Returns a list of existing groups
        """
        server = self.entity.jid.getDomain()
        answer = self._send_xmlrpc_call(self.xmlrpc_server.srg_list, {"host": server})
        groups = answer["groups"]
        ret = []

        for group in groups:
            answer = self._send_xmlrpc_call(self.xmlrpc_server.srg_get_info, {"host": server, "group": group["id"]})
            informations = answer["informations"]
            for info in informations:
                if info['information'][0]["key"] == "name":
                    displayed_name = info['information'][1]["value"]
                if info['information'][0]["key"] == "description":
                    description = info['information'][1]["value"]
            info = {"id": group["id"], "displayed_name": displayed_name.replace("\"", ""), "description": description.replace("\"", ""), "members": []}
            answer  = self._send_xmlrpc_call(self.xmlrpc_server.srg_get_members, {"host": server, "group": group["id"]})
            members = answer["members"]
            for member in members:
                info["members"].append(member["member"])
            ret.append(info)
        return ret

    def group_add_users(self, ID, users):
        """
        Add users into a group
        @type ID: string
        @param ID: the ID of the group
        @type users: list
        @param users: list of the users to add in the group
        """
        server = self.entity.jid.getDomain()
        for user in users:
            userJID = xmpp.JID(user)
            answer = self._send_xmlrpc_call(self.xmlrpc_server.srg_user_add, {"user": userJID.getNode(), "host": userJID.getDomain(), "group": ID, "grouphost": server})
            if not answer['res'] == 0:
                raise Exception("Cannot add user to shared roster group. %s" % str(answer))
            self.entity.log.info("XMPPSERVER: Adding user %s into shared group %s" % (userJID, ID))
        self.entity.push_change("xmppserver:groups", "usersadded")

    def group_delete_users(self, ID, users):
        """
        Delete users from a group
        @type ID: string
        @param ID: the ID of the group
        @type users: list
        @param users: list of users to remove
        """
        server = self.entity.jid.getDomain()
        for user in users:
            userJID = xmpp.JID(user)
            answer  = self._send_xmlrpc_call(self.xmlrpc_server.srg_user_del, {"user": userJID.getNode(), "host": userJID.getDomain(), "group": ID, "grouphost": server})
            if not answer['res'] == 0:
                raise Exception("Cannot remove user from shared roster group. %s" % str(answer))
            self.entity.log.info("XMPPSERVER: Removing user %s from shared group %s" % (userJID, ID))
        self.entity.push_change("xmppserver:groups", "usersdeleted")
