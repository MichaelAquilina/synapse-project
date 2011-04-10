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
using Cairo;

namespace Synapse.Gui
{
  public class ViewTest : Synapse.Gui.View
  {
    construct {
      build_ui ();
    }
    
    private NamedIcon source_icon;
    private SmartLabel source_label;
    private NamedIcon action_icon;
    private SmartLabel action_label;
    private NamedIcon target_icon;
    private SmartLabel target_label;
    
    private SmartLabel description_label;
    
    private static const int BORDER_RADIUS = 10;
    
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
        source_label = new SmartLabel ();
        source_label.set_ellipsize (Pango.EllipsizeMode.END);
        source_label.size = SmartLabel.Size.LARGE;
        source_label.min_size = SmartLabel.Size.X_SMALL;
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
        action_label = new SmartLabel ();
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
        target_label = new SmartLabel ();
        target_label.set_ellipsize (Pango.EllipsizeMode.END);
        vb.pack_start (target_label, true);
        hb.pack_start (vb);
      }
      
      vb = new VBox (false, 5);
      vb.pack_start (hb);
      
      description_label = new SmartLabel ();
      description_label.size = description_label.Size.MEDIUM;
      //description_label.set_ellipsize (Pango.EllipsizeMode.END);
      description_label.set_animation_enabled (true);
      vb.pack_start (description_label, false);
      
      vb.show_all ();
      
      vb.border_width = BORDER_RADIUS;
      this.add (vb);
      this.border_width = SHADOW_SIZE;
    }
    
    protected override void paint_background (Cairo.Context ctx, int width, int height)
    {
      double r = 0, b = 0, g = 0;
      ctx.translate (SHADOW_SIZE, SHADOW_SIZE);
      width -= SHADOW_SIZE * 2;
      height -= SHADOW_SIZE * 2;
      // shadow
      ctx.set_operator (Operator.SOURCE);
      ctx.translate (0.5, 0.5);
      Utils.cairo_make_shadow_for_rect (ctx, 0, 0, width - 1, height - 1, BORDER_RADIUS, r, g, b, SHADOW_SIZE);
      ctx.translate (-0.5, -0.5);
      
      ctx.save ();
      // pattern
      Pattern pat = new Pattern.linear(0, 0, 0, height);
      r = g = b = 0.15;
      ch.get_color_colorized (ref r, ref g, ref b, ch.StyleType.BG, StateType.SELECTED);
      pat.add_color_stop_rgba (0.0, r, g, b, 0.95);
      r = g = b = 0.5;
      ch.get_color_colorized (ref r, ref g, ref b, ch.StyleType.BG, StateType.SELECTED);
      pat.add_color_stop_rgba (1.0, r, g, b, 1.0);
      Utils.cairo_rounded_rect (ctx, 0, 0, width, height, BORDER_RADIUS);
      ctx.set_source (pat);
      ctx.set_operator (Operator.SOURCE);
      ctx.clip ();
      ctx.paint ();
      ctx.restore ();
    }
    
    private void update_description (SearchingFor what)
    {
      description_label.set_markup (Utils.markup_string_with_search (
                  Utils.get_printable_description (this.model.focus[what].value),
                  this.model.query[what], ""));
    }
    
    public override void update_focused_source ()
    {
      if (this.model.focus[SearchingFor.SOURCES].value != null)
      {
        source_icon.set_icon_name (this.model.focus[SearchingFor.SOURCES].value.icon_name, IconSize.DND);
        source_label.set_markup (Gui.Utils.markup_string_with_search (this.model.focus[SearchingFor.SOURCES].value.title, 
                                                                      this.model.query[SearchingFor.SOURCES], ""));
        if (this.model.searching_for == SearchingFor.SOURCES) update_description (SearchingFor.SOURCES);
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
                                                                      this.model.query[SearchingFor.ACTIONS], ""));
        if (this.model.searching_for == SearchingFor.ACTIONS) update_description (SearchingFor.ACTIONS);
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
                                                                      this.model.query[SearchingFor.TARGETS], ""));
        if (this.model.searching_for == SearchingFor.TARGETS) update_description (SearchingFor.TARGETS);
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
    public override void update_searching_for ()
    {
      if (this.model.focus[this.model.searching_for].value != null)
        update_description (this.model.searching_for);
    }
  }
}
