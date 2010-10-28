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

namespace Sezen
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
}

