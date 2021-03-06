import sys
import dbus
import dbus.service
import dbus.mainloop.glib


class SELinuxDBus (object):

    def __init__(self):
        self.bus = dbus.SystemBus()
        self.dbus_object = self.bus.get_object("org.selinux", "/org/selinux/object")

    def semanage(self, buf):
        ret = self.dbus_object.semanage(buf, dbus_interface="org.selinux")
        return ret

    def restorecon(self, path):
        ret = self.dbus_object.restorecon(path, dbus_interface="org.selinux")
        return ret

    def setenforce(self, value):
        ret = self.dbus_object.setenforce(value, dbus_interface="org.selinux")
        return ret

    def customized(self):
        ret = self.dbus_object.customized(dbus_interface="org.selinux")
        return ret

    def semodule_list(self):
        ret = self.dbus_object.semodule_list(dbus_interface="org.selinux")
        return ret

    def relabel_on_boot(self, value):
        ret = self.dbus_object.relabel_on_boot(value, dbus_interface="org.selinux")
        return ret

    def change_default_mode(self, value):
        ret = self.dbus_object.change_default_mode(value, dbus_interface="org.selinux")
        return ret

    def change_default_policy(self, value):
        ret = self.dbus_object.change_default_policy(value, dbus_interface="org.selinux")
        return ret

if __name__ == "__main__":
    try:
        dbus_proxy = SELinuxDBus()
        resp = dbus_proxy.setenforce(int(sys.argv[1]))
        print(resp)
    except dbus.DBusException as e:
        print(e)
