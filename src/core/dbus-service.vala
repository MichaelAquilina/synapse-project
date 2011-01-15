/*
 * Copyright (C) 2010 Michal Hruby <michal.mhr@gmail.com>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authored by Michal Hruby <michal.mhr@gmail.com>
 *
 */

namespace Synapse
{
  [DBus (name = "org.freedesktop.DBus")]
  public interface FreeDesktopDBus : GLib.Object
  {
    public const string UNIQUE_NAME = "org.freedesktop.DBus";
    public const string OBJECT_PATH = "/org/freedesktop/DBus";
    public const string INTERFACE_NAME = "org.freedesktop.DBus";

    public abstract async string[] list_queued_owners (string name) throws DBus.Error;
    public abstract async string[] list_names () throws DBus.Error;
    public abstract async string[] list_activatable_names () throws DBus.Error;
    public abstract async bool name_has_owner (string name) throws DBus.Error;
    public signal void name_owner_changed (string name,
                                           string old_owner,
                                           string new_owner);
    public abstract async uint32 start_service_by_name (string name,
                                               uint32 flags) throws DBus.Error;
    public abstract async string get_name_owner (string name) throws DBus.Error;
  }
  
  public class DBusService : Object
  {
    private DBus.Connection connection;
    private FreeDesktopDBus proxy;
    private Gee.Set<string> owned_names;
    private Gee.Set<string> activatable_names;
    private Gee.Set<string> system_activatable_names;
    
    public bool initialized { get; private set; default = false; }

    // singleton that can be easily destroyed
    public static DBusService get_default ()
    {
      return instance ?? new DBusService ();
    }

    private DBusService ()
    {
    }
    
    private static unowned DBusService? instance;
    construct
    {
      instance = this;
      owned_names = new Gee.HashSet<string> ();
      activatable_names = new Gee.HashSet<string> ();
      system_activatable_names = new Gee.HashSet<string> ();

      initialize ();
    }
    
    ~DBusService ()
    {
      instance = null;
    }
    
    private void name_owner_changed (FreeDesktopDBus sender,
                                     string name,
                                     string old_owner,
                                     string new_owner)
    {
      if (name.has_prefix (":")) return;

      if (old_owner == "")
      {
        owned_names.add (name);
      }
      else if (new_owner == "")
      {
        owned_names.remove (name);
      }
    }
    
    public bool name_has_owner (string name)
    {
      return name in owned_names;
    }
    
    public bool name_is_activatable (string name)
    {
      return name in activatable_names;
    }
    
    public bool service_is_available (string name)
    {
      return name in system_activatable_names;
    }
    
    public static DBus.Connection get_session_bus ()
    {
      return get_default ().connection;
    }

    public signal void initialization_done ();
    
    private async void initialize ()
    {
      string[] names;
      try
      {
        connection = DBus.Bus.get (DBus.BusType.SESSION);
        proxy = (FreeDesktopDBus)
          connection.get_object (FreeDesktopDBus.UNIQUE_NAME,
                                 FreeDesktopDBus.OBJECT_PATH,
                                 FreeDesktopDBus.INTERFACE_NAME);

        proxy.name_owner_changed.connect (this.name_owner_changed);
        names = yield proxy.list_names ();
        foreach (unowned string name in names)
        {
          if (name.has_prefix (":")) continue;
          owned_names.add (name);
        }
        
        names = yield proxy.list_activatable_names ();
        foreach (unowned string session_act in names)
        {
          activatable_names.add (session_act);
        }
      }
      catch (Error err)
      {
        warning ("%s", err.message);
      }

      try
      {
        var sys_connection = DBus.Bus.get (DBus.BusType.SYSTEM);
        var sys_proxy = (FreeDesktopDBus)
          sys_connection.get_object (FreeDesktopDBus.UNIQUE_NAME,
                                     FreeDesktopDBus.OBJECT_PATH,
                                     FreeDesktopDBus.INTERFACE_NAME);

        names = yield sys_proxy.list_activatable_names ();
        foreach (unowned string system_act in names)
        {
          system_activatable_names.add (system_act);
        }
      }
      catch (Error sys_err)
      {
        warning ("%s", sys_err.message);
      }
      
      initialized = true;
      initialization_done ();
    }
  }
}

