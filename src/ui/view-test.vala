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
    
    private NamedIcon match_icon;
    private Label match_label;
    
    private void build_ui ()
    {
      HBox hb = new HBox (false, 5);
      match_icon = new NamedIcon ();
      match_icon.set_icon_name ("synapse", IconSize.DND);
      match_icon.set_size_request (128, 128);
      match_icon.set_pixel_size (128);
      hb.pack_start (match_icon, false);
      match_label = new Label ("");
      hb.pack_start (match_label, true);
      
      hb.show_all ();
      
      this.add (hb);
    }
    
    public override void update_focused_source ()
    {
      if (this.model.focus[SearchingFor.SOURCES].value != null)
      {
        match_icon.set_icon_name (this.model.focus[SearchingFor.SOURCES].value.icon_name, IconSize.DND);
        match_label.set_markup (Gui.Utils.markup_string_with_search (this.model.focus[SearchingFor.SOURCES].value.title, 
                                                                     this.model.query[SearchingFor.SOURCES]));
      }
      else
      {
        match_icon.set_icon_name ("synapse", IconSize.DND);
        match_label.set_text ("search");
      }
    }
    public override void update_focused_action ()
    {
    
    }
    public override void update_focused_target ()
    {
    
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
