using Gtk;
using Gdk;

public class Tootle.Views.Notifications : Views.Abstract {

    private int64 last_id = 0;
    private bool force_dot = false;

    public Notifications () {
        base ();
        content.remove.connect (on_remove);
        //accounts.switched.connect (on_account_changed);
        app.refresh.connect (on_refresh);
        network.notification.connect (prepend);

        request ();
    }

    private bool has_unread () {
        if (accounts.active == null)
            return false;
        return last_id > accounts.active.last_seen_notification || force_dot;
    }

    public override string get_icon () {
        if (has_unread ())
            return Desktop.fallback_icon ("notification-new-symbolic", "user-available-symbolic");
        else
            return Desktop.fallback_icon ("notification-symbolic", "user-invisible-symbolic");
    }

    public override string get_name () {
        return _("Notifications");
    }

    public void prepend (API.Notification notification) {
        append (notification, true);
    }

    public void append (API.Notification notification, bool reverse = false) {
        if (empty != null)
            empty.destroy ();

        var separator = new Separator (Orientation.HORIZONTAL);
        separator.show ();

        var widget = new Widgets.Notification (notification);
        widget.separator = separator;
        content.pack_start (separator, false, false, 0);
        content.pack_start (widget, false, false, 0);

        if (reverse) {
            content.reorder_child (widget, 0);
            content.reorder_child (separator, 0);

            if (!current) {
                force_dot = true;
                accounts.active.has_unread_notifications = force_dot;
            }
        }

        if (notification.id > last_id)
            last_id = notification.id;

        if (has_unread ()) {
            accounts.save ();
            image.icon_name = get_icon ();
        }
    }

    public override void on_set_current () {
        var account = accounts.active;
        if (has_unread ()) {
            force_dot = false;
            account.has_unread_notifications = force_dot;
            account.last_seen_notification = last_id;
            accounts.save ();
            image.icon_name = get_icon ();
        }
    }

    public virtual void on_remove (Widget widget) {
        if (!(widget is Widgets.Notification))
            return;

        empty_state ();
    }

    public override bool empty_state () {
        var is_empty = base.empty_state ();
        if (image != null && is_empty)
            image.icon_name = get_icon ();

        return is_empty;
    }

    public virtual void on_refresh () {
        clear ();
        request ();
    }

    public virtual void on_account_changed (API.Account? account) {
        if (account == null)
            return;

        last_id = accounts.active.last_seen_notification;
        force_dot = accounts.active.has_unread_notifications;
        on_refresh ();
    }

    public void request () {
        if (accounts.active == null) {
            empty_state ();
            return;
        }

        accounts.active.cached_notifications.@foreach (notification => {
            append (notification);
            return true;
        });

        var msg = new Soup.Message ("GET", @"$(accounts.active.instance)/api/v1/follow_requests");
        network.inject (msg, Network.INJECT_TOKEN);
        network.queue (msg, (sess, mess) => {
            network.parse_array (mess).foreach_element ((array, i, node) => {
                var obj = node.get_object ();
                if (obj != null){
                    var notification = API.Notification.parse_follow_request (obj);
                    append (notification);
                }
            });
        });

        var msg2 = new Soup.Message ("GET", @"$(accounts.active.instance)/api/v1/notifications?limit=30");
        network.inject (msg2, Network.INJECT_TOKEN);
        network.queue (msg2, (sess, mess) => {
            network.parse_array (mess).foreach_element ((array, i, node) => {
                var obj = node.get_object ();
                if (obj != null){
                    var notification = API.Notification.parse (obj);
                    append (notification);
                }
            });
        });

        empty_state ();
    }

}
