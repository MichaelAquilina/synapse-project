/*
 * Copyright (C) 2010 Michal Hruby <michal.mhr@gmail.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301  USA.
 *
 * Authored by Michal Hruby <michal.mhr@gmail.com>
 *
 */

namespace Synapse
{
  [DBus (name = "org.freedesktop.UPower")]
  public interface UPowerObject: Object
  {
    public const string UNIQUE_NAME = "org.freedesktop.UPower";
    public const string OBJECT_PATH = "/org/freedesktop/UPower";
    public const string INTERFACE_NAME = "org.freedesktop.UPower";

    public abstract async void hibernate () throws DBus.Error;
    public abstract async void suspend () throws DBus.Error;
    public abstract async bool hibernate_allowed () throws DBus.Error;
    public abstract async bool suspend_allowed () throws DBus.Error;
    
    public abstract async void about_to_sleep () throws DBus.Error;
  }

  [DBus (name = "org.freedesktop.ConsoleKit.Manager")]
  public interface ConsoleKitObject: Object
  {
    public const string UNIQUE_NAME = "org.freedesktop.ConsoleKit";
    public const string OBJECT_PATH = "/org/freedesktop/ConsoleKit/Manager";
    public const string INTERFACE_NAME = "org.freedesktop.ConsoleKit.Manager";
    
    public abstract void restart () throws DBus.Error;
    public abstract void stop () throws DBus.Error;
    public abstract async bool can_restart () throws DBus.Error;
    public abstract async bool can_stop () throws DBus.Error;
  }

  public class SystemManagementPlugin: Object, Activatable, ItemProvider
  {
    public bool enabled { get; set; default = true; }

    public void activate ()
    {
      
    }

    public void deactivate ()
    {
      
    }

    private abstract class SystemAction: Object, Match
    {
      // for Match interface
      public string title { get; construct set; }
      public string description { get; set; default = ""; }
      public string icon_name { get; construct set; default = ""; }
      public bool has_thumbnail { get; construct set; default = false; }
      public string thumbnail_path { get; construct set; }
      public MatchType match_type { get; construct set; }

      public void execute (Match? match)
      {
        this.do_action ();
      }

      public abstract void do_action ();
      public abstract bool action_allowed ();
    }

    private class SuspendAction: SystemAction
    {
      public SuspendAction ()
      {
        Object (match_type: MatchType.ACTION, title: _ ("Suspend"),
                description: _ ("Put your computer into suspend mode"),
                icon_name: "system-suspend", has_thumbnail: false);
      }

      construct
      {
        check_allowed.begin ();
      }

      private async void check_allowed ()
      {
        try
        {
          var connection = DBus.Bus.get (DBus.BusType.SYSTEM);
          var dbus_interface = (UPowerObject)
            connection.get_object (UPowerObject.UNIQUE_NAME,
                                   UPowerObject.OBJECT_PATH,
                                   UPowerObject.INTERFACE_NAME);

          allowed = yield dbus_interface.hibernate_allowed ();
        }
        catch (DBus.Error err)
        {
          allowed = false;
        }
      }

      private bool allowed = false;

      public override bool action_allowed ()
      {
        return allowed;
      }
      
      private async void do_suspend ()
      {
        try
        {
          var connection = DBus.Bus.get (DBus.BusType.SYSTEM);
          var dbus_interface = (UPowerObject)
            connection.get_object (UPowerObject.UNIQUE_NAME,
                                   UPowerObject.OBJECT_PATH,
                                   UPowerObject.INTERFACE_NAME);

          yield dbus_interface.about_to_sleep ();
          // yea kinda nasty
          GnomeScreenSaverPlugin.lock_screen ();
          // wait 2 seconds
          Timeout.add (2000, do_suspend.callback);
          yield;

          yield dbus_interface.suspend ();
        }
        catch (DBus.Error err)
        {
          warning ("%s", err.message);
        }
      }

      public override void do_action ()
      {
        do_suspend.begin ();
      }
    }

    private class HibernateAction: SystemAction
    {
      public HibernateAction ()
      {
        Object (match_type: MatchType.ACTION, title: _ ("Hibernate"),
                description: _ ("Put your computer into hibernation mode"),
                icon_name: "system-hibernate", has_thumbnail: false);
      }

      construct
      {
        check_allowed.begin ();
      }

      private async void check_allowed ()
      {
        try
        {
          var connection = DBus.Bus.get (DBus.BusType.SYSTEM);
          var dbus_interface = (UPowerObject)
            connection.get_object (UPowerObject.UNIQUE_NAME,
                                   UPowerObject.OBJECT_PATH,
                                   UPowerObject.INTERFACE_NAME);

          allowed = yield dbus_interface.hibernate_allowed ();
        }
        catch (DBus.Error err)
        {
          allowed = false;
        }
      }

      private bool allowed = false;

      public override bool action_allowed ()
      {
        return allowed;
      }
      
      private async void do_hibernate ()
      {
        try
        {
          var connection = DBus.Bus.get (DBus.BusType.SYSTEM);
          var dbus_interface = (UPowerObject)
            connection.get_object (UPowerObject.UNIQUE_NAME,
                                   UPowerObject.OBJECT_PATH,
                                   UPowerObject.INTERFACE_NAME);

          yield dbus_interface.about_to_sleep ();
          // yea kinda nasty
          GnomeScreenSaverPlugin.lock_screen ();
          // wait 2 seconds
          Timeout.add (2000, do_hibernate.callback);
          yield;
          dbus_interface.hibernate ();
        }
        catch (DBus.Error err)
        {
          warning ("%s", err.message);
        }
      }

      public override void do_action ()
      {
        do_hibernate.begin ();
      }
    }

    private class ShutdownAction: SystemAction
    {
      public ShutdownAction ()
      {
        Object (match_type: MatchType.ACTION, title: _ ("Shut Down"),
                description: _ ("Turn your computer off"),
                icon_name: "system-shutdown", has_thumbnail: false);
      }

      construct
      {
        check_allowed.begin ();
      }

      private async void check_allowed ()
      {
        try
        {
          var connection = DBus.Bus.get (DBus.BusType.SYSTEM);
          var dbus_interface = (ConsoleKitObject)
            connection.get_object (ConsoleKitObject.UNIQUE_NAME,
                                   ConsoleKitObject.OBJECT_PATH,
                                   ConsoleKitObject.INTERFACE_NAME);

          allowed = yield dbus_interface.can_stop ();
        }
        catch (DBus.Error err)
        {
          allowed = false;
        }
      }

      private bool allowed = false;

      public override bool action_allowed ()
      {
        return allowed;
      }

      public override void do_action ()
      {
        try
        {
          var connection = DBus.Bus.get (DBus.BusType.SYSTEM);
          var dbus_interface = (ConsoleKitObject)
            connection.get_object (ConsoleKitObject.UNIQUE_NAME,
                                   ConsoleKitObject.OBJECT_PATH,
                                   ConsoleKitObject.INTERFACE_NAME);

          dbus_interface.stop ();
        }
        catch (DBus.Error err)
        {
          warning ("%s", err.message);
        }
      }
    }

    private class RestartAction: SystemAction
    {
      public RestartAction ()
      {
        Object (match_type: MatchType.ACTION, title: _ ("Restart"),
                description: _ ("Restart your computer"),
                icon_name: "system-restart", has_thumbnail: false);
      }

      construct
      {
        check_allowed.begin ();
      }

      private async void check_allowed ()
      {
        try
        {
          var connection = DBus.Bus.get (DBus.BusType.SYSTEM);
          var dbus_interface = (ConsoleKitObject)
            connection.get_object (ConsoleKitObject.UNIQUE_NAME,
                                   ConsoleKitObject.OBJECT_PATH,
                                   ConsoleKitObject.INTERFACE_NAME);

          allowed = yield dbus_interface.can_restart ();
        }
        catch (DBus.Error err)
        {
          allowed = false;
        }
      }

      private bool allowed = false;

      public override bool action_allowed ()
      {
        return allowed;
      }

      public override void do_action ()
      {
        try
        {
          var connection = DBus.Bus.get (DBus.BusType.SYSTEM);
          var dbus_interface = (ConsoleKitObject)
            connection.get_object (ConsoleKitObject.UNIQUE_NAME,
                                   ConsoleKitObject.OBJECT_PATH,
                                   ConsoleKitObject.INTERFACE_NAME);

          dbus_interface.restart ();
        }
        catch (DBus.Error err)
        {
          warning ("%s", err.message);
        }
      }
    }

    static void register_plugin ()
    {
      DataSink.PluginRegistry.get_default ().register_plugin (
        typeof (SystemManagementPlugin),
        "System Management",
        _ ("Suspend, hibernate, restart or shutdown your computer."),
        "system-restart",
        register_plugin,
        DBusService.get_default ().service_is_available (ConsoleKitObject.UNIQUE_NAME),
        _ ("ConsoleKit wasn't found")
      );
    }

    static construct
    {
      register_plugin ();
    }

    private Gee.List<SystemAction> actions;

    construct
    {
      actions = new Gee.LinkedList<SystemAction> ();
      actions.add (new SuspendAction ());
      actions.add (new HibernateAction ());
      actions.add (new ShutdownAction ());
      actions.add (new RestartAction ());
    }

    public async ResultSet? search (Query q) throws SearchError
    {
      // we only search for actions
      if (!(QueryFlags.ACTIONS in q.query_type)) return null;

      var result = new ResultSet ();
      
      var matchers = Query.get_matchers_for_query (q.query_string, 0,
        RegexCompileFlags.OPTIMIZE | RegexCompileFlags.CASELESS);

      foreach (var action in actions)
      {
        if (!action.action_allowed ()) continue;
        foreach (var matcher in matchers)
        {
          if (matcher.key.match (action.title))
          {
            result.add (action, matcher.value - Match.Score.INCREMENT_SMALL);
            break;
          }
        }
      }

      q.check_cancellable ();

      return result;
    }
  }
}
