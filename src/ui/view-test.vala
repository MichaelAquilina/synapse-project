/*
 * Copyright (C) 2010 Michal Hruby <michal.mhr@gmail.com>
 * Copyright (C) 2010 Alberto Aldegheri <albyrock87+dev@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authored by Alberto Aldegheri <albyrock87+dev@gmail.com>
 *
 */

using Gee;
using Gtk;

namespace Synapse.Gui
{
  public class TestView : Synapse.View
  {
    construct {
      build_ui ();
    }
    
    private NamedIcon source_icon;
    private Label source_label;
    private NamedIcon action_icon;
    private Label action_label;
    private NamedIcon target_icon;
    private Label target_label;
    
    private void build_ui ()
    {
      HBox hb = new HBox (false, 5);
      
      VBox vb = null;
      
      {
        vb = new VBox (false, 5);
        source_icon = new NamedIcon ();
        source_icon.set_icon_name ("synapse", IconSize.DND);
        source_icon.set_size_request (128, 128);
        source_icon.set_pixel_size (128);
        vb.pack_start (source_icon, false);
        source_label = new Label ("");
        source_label.set_ellipsize (Pango.EllipsizeMode.END);
        vb.pack_start (source_label, true);
        hb.pack_start (vb);
      }
      
      {
        vb = new VBox (false, 5);
        action_icon = new NamedIcon ();
        action_icon.set_icon_name ("synapse", IconSize.DND);
        action_icon.set_size_request (128, 128);
        action_icon.set_pixel_size (128);
        vb.pack_start (action_icon, false);
        action_label = new Label ("");
        action_label.set_ellipsize (Pango.EllipsizeMode.END);
        vb.pack_start (action_label, true);
        hb.pack_start (vb);
      }
      
      {
        vb = new VBox (false, 5);
        target_icon = new NamedIcon ();
        target_icon.set_icon_name ("synapse", IconSize.DND);
        target_icon.set_size_request (128, 128);
        target_icon.set_pixel_size (128);
        vb.pack_start (target_icon, false);
        target_label = new Label ("");
        target_label.set_ellipsize (Pango.EllipsizeMode.END);
        vb.pack_start (target_label, true);
        hb.pack_start (vb);
      }
      
      hb.show_all ();
      
      this.add (hb);
    }
    
    public override void update_focused_source ()
    {
      if (this.model.focus[SearchingFor.SOURCES].value != null)
      {
        source_icon.set_icon_name (this.model.focus[SearchingFor.SOURCES].value.icon_name, IconSize.DND);
        source_label.set_markup (Gui.Utils.markup_string_with_search (this.model.focus[SearchingFor.SOURCES].value.title, 
                                                                     this.model.query[SearchingFor.SOURCES]));
      }
      else
      {
        source_icon.set_icon_name ("synapse", IconSize.DND);
        source_label.set_text ("search");
      }
    }
    public override void update_focused_action ()
    {
      if (this.model.focus[SearchingFor.ACTIONS].value != null)
      {
        action_icon.set_icon_name (this.model.focus[SearchingFor.ACTIONS].value.icon_name, IconSize.DND);
        action_label.set_markup (Gui.Utils.markup_string_with_search (this.model.focus[SearchingFor.ACTIONS].value.title, 
                                                                     this.model.query[SearchingFor.ACTIONS]));
      }
      else
      {
        action_icon.set_icon_name ("synapse", IconSize.DND);
        action_label.set_text ("search");
      }
    }
    public override void update_focused_target ()
    {
      if (this.model.focus[SearchingFor.TARGETS].value != null)
      {
        target_icon.set_icon_name (this.model.focus[SearchingFor.TARGETS].value.icon_name, IconSize.DND);
        target_label.set_markup (Gui.Utils.markup_string_with_search (this.model.focus[SearchingFor.TARGETS].value.title, 
                                                                     this.model.query[SearchingFor.TARGETS]));
      }
      else
      {
        target_icon.set_icon_name ("synapse", IconSize.DND);
        target_label.set_text ("search");
      }
    }
    public override void update_sources ()
    {
    
    }
    public override void update_actions ()
    {
    
    }
    public override void update_targets ()
    {
    
    }
    public override void update_selected_category ()
    {
    
    }
  }
}
