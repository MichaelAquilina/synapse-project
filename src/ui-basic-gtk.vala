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

using Gtk;

namespace Synapse.Gui
{
  public class SynapseWindow: Window
  {
    public SynapseWindow ()
    {
      GLib.Object (border_width: 4);

      build_ui ();
      this.set_position (WindowPosition.CENTER);
    }

    private IMContext im_context;
    private DataSink data_sink;
    private Cancellable last_search_cancellable = new Cancellable ();

    construct
    {
      data_sink = new DataSink ();

      set_decorated (false);
      set_resizable (false);

      im_context = new IMMulticontext ();
      im_context.set_use_preedit (false);
      im_context.commit.connect (this.search_add_char);
      im_context.focus_in ();

      this.notify["search-string"].connect (() =>
      {
        bool search_empty = search_string == null || search_string == "";

        string search_type = "Local content"; // FIXME: un-hardcode
        string label = search_empty ?
          "Search > %s".printf (search_type) :
          "Search > %s > %s".printf (search_type, search_string);
        head_label.set_text (label);

        last_search_cancellable.cancel ();
        last_search_cancellable = new Cancellable ();

        if (!search_empty)
        {
          uint timer_id;
          timer_id = Timeout.add (150, () =>
          {
            debug ("search is taking quite long, we should display something");
            timer_id = 0;
            return false;
          });
          data_sink.search (this.search_string, QueryFlags.LOCAL_CONTENT,
                            null, last_search_cancellable,
                            (obj, res) =>
          {
            if (timer_id != 0)
            {
              Source.remove (timer_id);
              debug ("the search was fast enough");
            }
            this.search_ready (obj, res);
          });
        }
        else
        {
          main_image.set_from_icon_name ("search", IconSize.DIALOG);
          main_label.set_text ("Type to search");
        }
      });
    }

    private void search_ready (GLib.Object? obj, AsyncResult res)
    {
      try
      {
        var results = data_sink.search.end (res);
        if (results.size > 0)
        {
          focus_match (results[0]);
        }
        else
        {
          focus_match (null);
          main_image.set_from_icon_name ("unknown", IconSize.DIALOG);
          main_label.set_text ("No results");
        }
      }
      catch (SearchError err)
      {
        // most likely cancelled
      }
      /*
      foreach (var match in results)
      {
        debug ("got match: %s", match.title);
      }
      */
    }

    public string search_string { get; private set; default = ""; }

    private void search_add_char (string chr)
    {
      search_string += chr;
    }

    private void search_delete_char ()
    {
      long len = search_string.length;
      if (len > 0)
      {
        search_string = search_string.substring (0, len - 1);
      }
      else
      {
        search_string = "";
      }
    }

    private void search_reset ()
    {
      search_string = "";
    }

    private int ICON_SIZE = 128;

    private Label head_label;
    private Image main_image;
    private Label main_label;
    private Image action_image;
    private Label action_label;

    private void build_ui ()
    {
      int im_size = ICON_SIZE * 5 / 4;
      var main_vbox = new VBox (false, 0);
      head_label = new Label ("Search > Local content");
      head_label.xalign =  0.0f;
      head_label.xpad = 2; head_label.ypad = 2;
      main_vbox.pack_start (head_label, false);

      var left_vbox = new VBox (false, 4);
      main_image = new Image ();
      main_image.set_pixel_size (ICON_SIZE);
      main_image.set_size_request (im_size, im_size);
      main_image.set_from_icon_name ("search", IconSize.DIALOG);

      main_label = new Label ("Type to search");
      main_label.set_ellipsize (Pango.EllipsizeMode.END);
      left_vbox.pack_start (main_image, false, true);
      left_vbox.pack_start (main_label, false, true);

      var right_vbox = new VBox (false, 4);
      action_image = new Image ();
      action_image.set_pixel_size (ICON_SIZE);
      action_image.set_size_request (im_size, im_size);
      action_image.set_from_icon_name ("system-run", IconSize.DIALOG);

      action_label = new Label (null);
      right_vbox.pack_start (action_image, false, true);
      right_vbox.pack_start (action_label, false, true);

      var hbox = new HBox (false, 6);
      hbox.pack_start (left_vbox);
      hbox.pack_start (right_vbox);
      main_vbox.pack_start (hbox, false, true, 4);

      var frame = new Frame (null);
      frame.shadow_type = ShadowType.OUT; //ETCHED_OUT;
      frame.add (main_vbox);
      frame.show_all ();

      this.add (frame);
    }

    private Match? current_match = null;
    private Match? current_action = null;

    public void focus_match (Match? match)
    {
      current_match = match;
      if (match != null)
      {
        var actions = data_sink.find_actions_for_match (match, null);
        current_action = actions.size > 0 ? actions[0] : null;
        try
        {
          GLib.Icon icon = GLib.Icon.new_for_string (match.has_thumbnail ?
            match.thumbnail_path : match.icon_name);
          main_image.set_from_gicon (icon, IconSize.DIALOG);
          icon.unref ();
        }
        catch (Error err)
        {
          main_image.set_from_icon_name ("missing-image", IconSize.DIALOG);
        }
        main_label.set_text (match.title);
        
        try
        {
          if (current_action != null)
          {
            action_label.set_text (current_action.title);
            var icon = GLib.Icon.new_for_string (current_action.icon_name);
            action_image.set_from_gicon (icon, IconSize.DIALOG);
            icon.unref ();
          }
        }
        catch (Error err)
        {
          action_image.set_from_icon_name ("missing-image", IconSize.DIALOG);
        }
      }
      else
      {
        action_label.set_text ("");
      }
    }

    private void quit ()
    {
      Gtk.main_quit ();
    }

    public void activate (uint event_time)
    {
      show ();
      present_with_time (event_time);
    }

    protected override bool key_press_event (Gdk.EventKey event)
    {
      if (im_context.filter_keypress (event)) return true;

      uint key = event.keyval;
      switch (key)
      {
        case Gdk.KeySyms.Return:
        case Gdk.KeySyms.KP_Enter:
        case Gdk.KeySyms.ISO_Enter:
          debug ("enter pressed");
          if (current_match != null && current_action != null)
          {
            current_action.execute (current_match);
            hide ();
            search_reset ();
          }
          break;
        case Gdk.KeySyms.Delete:
        case Gdk.KeySyms.BackSpace:
          search_delete_char ();
          break;
        case Gdk.KeySyms.Escape:
          debug ("escape");
          if (search_string != "")
          {
            search_reset ();
          }
          else
          {
            hide ();
            //quit (); // for debug
          }
          break;
        default:
          debug ("im_context didn't filter...");
          break;
      }

      return true;
    }

    public static int main (string[] argv)
    {
      Gtk.init (ref argv);
      var window = new SynapseWindow ();
      window.show_all ();

      var registry = GtkHotkey.Registry.get_default ();
      GtkHotkey.Info hotkey;
      try
      {
        if (registry.has_hotkey ("sezen2", "activate"))
        {
          hotkey = registry.get_hotkey ("sezen2", "activate");
        }
        else
        {
          hotkey = new GtkHotkey.Info ("sezen2", "activate",
                                       "<Control>space", null);
          registry.store_hotkey (hotkey);
        }
        debug ("Binding activation to %s", hotkey.signature);
        hotkey.bind ();
        hotkey.activated.connect (window.activate);
      }
      catch (Error err)
      {
        warning ("%s", err.message);
      }

      Gtk.main ();
      window.destroy ();
      return 0;
    }
  }
}
