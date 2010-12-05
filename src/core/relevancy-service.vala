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
  public class RelevancyService : GLib.Object
  {
    // singleton that can be easily destroyed
    private static unowned RelevancyService? instance;
    public static RelevancyService get_default ()
    {
      return instance ?? new RelevancyService ();
    }

    private RelevancyService ()
    {
    }

    ~RelevancyService ()
    {
    }

    construct
    {
      instance = this;
      this.add_weak_pointer (&instance);
      
      initialize_relevancy_backend ();
    }
    
    private RelevancyBackend backend;
    
    private void initialize_relevancy_backend ()
    {
#if HAVE_ZEITGEIST
      backend = new ZeitgeistBackend ();
#endif
    }
    
    public float get_application_popularity (string desktop_id)
    {
      return_if_fail (backend != null);
      return backend.get_application_popularity (desktop_id);
    }

    public float get_uri_popularity (string uri)
    {
      return_if_fail (backend != null);
      return backend.get_uri_popularity (uri);
    }
    
    public void application_launched (AppInfo app_info)
    {
      return_if_fail (backend != null);
      backend.application_launched (app_info);
    }
    
    private abstract class RelevancyBackend: Object
    {
      public abstract float get_application_popularity (string desktop_id);
      public abstract float get_uri_popularity (string uri);

      public abstract void application_launched (AppInfo app_info);
    }

#if HAVE_ZEITGEIST
    private class ZeitgeistBackend: RelevancyBackend
    {
      Zeitgeist.Log zg_log;
      
      construct
      {
        zg_log = new Zeitgeist.Log ();
      }
      
      public override float get_application_popularity (string desktop_id)
      {
        return 0.0f;
      }
      
      public override float get_uri_popularity (string uri)
      {
        return 0.0f;
      }
      
      public override void application_launched (AppInfo app_info)
      {
        // detect if the Zeitgeist GIO module is installed
        Type zg_gio_module = Type.from_name ("GAppLaunchHandlerZeitgeist");
        if (zg_gio_module != 0 || !app_info.should_show ()) return;

        string app_uri = null;
        if (app_info.get_id () != null)
        {
          app_uri = "application://" + app_info.get_id ();
        }
        else if (app_info is DesktopAppInfo)
        {
          var basename = Path.get_basename ((app_info as DesktopAppInfo).get_filename ());
          app_uri = "application://" + basename;
        }

        push_app_launch (app_uri, app_info.get_display_name ());
      }

      private void push_app_launch (string app_uri, string? display_name)
      {
        //debug ("pushing launch event: %s [%s]", app_uri, display_name);
        var event = new Zeitgeist.Event ();
        var subject = new Zeitgeist.Subject ();

        event.set_actor ("application://synapse.desktop");
        event.set_interpretation (Zeitgeist.ZG_ACCESS_EVENT);
        event.set_manifestation (Zeitgeist.ZG_USER_ACTIVITY);
        event.add_subject (subject);

        subject.set_uri (app_uri);
        subject.set_interpretation (Zeitgeist.NFO_SOFTWARE);
        subject.set_manifestation (Zeitgeist.NFO_SOFTWARE_ITEM);
        subject.set_mimetype ("application/x-desktop");
        subject.set_text (display_name);

        zg_log.insert_events_no_reply (event, null);
      }
    }
#endif
  }
}

