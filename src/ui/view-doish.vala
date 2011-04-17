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
  public class ViewDoish : Synapse.Gui.View
  {
    construct {
      
    }
    
    static construct
    {
      var spacing = new GLib.ParamSpecInt ("pane-spacing",
                                             "Pane Spacing",
                                             "The space between two panes in Doish theme",
                                             5, 100, 30,
                                             GLib.ParamFlags.READABLE);
      var icon_size = new GLib.ParamSpecInt ("icon-size",
                                             "Icon Size",
                                             "The size of icons in Doish theme",
                                             32, 192, 128,
                                             GLib.ParamFlags.READABLE);
      var title_max = new GLib.ParamSpecString ("title-size",
                                                "Title Font Size",
                                                "The standard size the match title in Pango absolute sizes (string)",
                                                "medium",
                                                GLib.ParamFlags.READABLE);
      var title_min = new GLib.ParamSpecString ("title-min-size",
                                                "Title minimum Font Size",
                                                "The minimum size the match title in Pango absolute sizes (string)",
                                                "small",
                                                GLib.ParamFlags.READABLE);
      var descr_max = new GLib.ParamSpecString ("description-size",
                                                "Title Font Size",
                                                "The standard size the match title in Pango absolute sizes (string)",
                                                "small",
                                                GLib.ParamFlags.READABLE);
      var descr_min = new GLib.ParamSpecString ("description-min-size",
                                                "Title minimum Font Size",
                                                "The minimum size the match title in Pango absolute sizes (string)",
                                                "x-small",
                                                GLib.ParamFlags.READABLE);
      
      install_style_property (spacing);
      install_style_property (icon_size);
      install_style_property (title_max);
      install_style_property (title_min);
      install_style_property (descr_max);
      install_style_property (descr_min);
    }
    
    public override void style_set (Gtk.Style? old)
    {
      base.style_set (old);

      int spacing, icon_size;
      string tmax, tmin, dmax, dmin;
      this.style.get (typeof(Synapse.Gui.ViewDoish), "pane-spacing", out spacing);
      this.style.get (typeof(Synapse.Gui.ViewDoish), "icon-size", out icon_size);
      this.style.get (typeof(Synapse.Gui.ViewDoish), "title-size", out tmax);
      this.style.get (typeof(Synapse.Gui.ViewDoish), "title-min-size", out tmin);
      this.style.get (typeof(Synapse.Gui.ViewDoish), "description-size", out dmax);
      this.style.get (typeof(Synapse.Gui.ViewDoish), "description-min-size", out dmin);
      
      sp1.set_size_request (spacing, -1);
      sp2.set_size_request (spacing, -1);

      source_icon.set_pixel_size (icon_size);
      action_icon.set_pixel_size (icon_size);
      target_icon.set_pixel_size (icon_size);
      spacer.set_size_request (1, SHADOW_SIZE + BORDER_RADIUS);
      source_label.size = SmartLabel.string_to_size (tmax);
      source_label.min_size = SmartLabel.string_to_size (tmin);
      action_label.size = SmartLabel.string_to_size (tmax);
      action_label.min_size = SmartLabel.string_to_size (tmin);
      target_label.size = SmartLabel.string_to_size (tmax);
      target_label.min_size = SmartLabel.string_to_size (tmin);
      description_label.size = SmartLabel.string_to_size (dmax);
      description_label.min_size = SmartLabel.string_to_size (dmin);
    }
    
    private NamedIcon source_icon;
    private NamedIcon action_icon;
    private NamedIcon target_icon;
    
    private SmartLabel source_label;
    private SmartLabel action_label;
    private SmartLabel target_label;
    private SmartLabel description_label;
    
    private Label spacer;
    
    private SelectionContainer results_container;
    
    private ResultBox results_sources;
    private ResultBox results_actions;
    private ResultBox results_targets;
    
    private MenuThrobber menuthrobber;
    
    private Box target_container;
    private Box container;
    
    private Box spane; //source and action panes
    private Box apane;
    private Box tpane;
    
    private Label sp1;
    private Label sp2;
    
    protected override void build_ui ()
    {
      /* Icons */
      source_icon = new NamedIcon ();
      action_icon = new NamedIcon ();
      target_icon = new NamedIcon ();
      source_icon.set_icon_name ("search", IconSize.DND);
      action_icon.clear ();
      target_icon.set_icon_name ("");
      
      source_icon.set_pixel_size (128);
      source_icon.xpad = 15;
      action_icon.set_pixel_size (128);
      action_icon.xpad = 15;
      target_icon.set_pixel_size (128);
      target_icon.xpad = 15;
      
      /* Labels */
      source_label = new SmartLabel ();
      source_label.set_ellipsize (Pango.EllipsizeMode.END);
      source_label.size = SmartLabel.Size.MEDIUM;
      source_label.min_size = SmartLabel.Size.SMALL;
      source_label.set_state (StateType.SELECTED);
      source_label.xalign = 0.5f;
      action_label = new SmartLabel ();
      action_label.set_ellipsize (Pango.EllipsizeMode.END);
      action_label.size = SmartLabel.Size.MEDIUM;
      action_label.min_size = SmartLabel.Size.SMALL;
      action_label.set_state (StateType.SELECTED);
      action_label.xalign = 0.5f;
      target_label = new SmartLabel ();
      target_label.set_ellipsize (Pango.EllipsizeMode.END);
      target_label.size = SmartLabel.Size.MEDIUM;
      target_label.min_size = SmartLabel.Size.SMALL;
      target_label.set_state (StateType.SELECTED);
      target_label.xalign = 0.5f;
      description_label = new SmartLabel ();
      description_label.size = SmartLabel.Size.SMALL;
      description_label.set_animation_enabled (true);
      description_label.set_state (StateType.SELECTED);
      description_label.xalign = 0.5f;
      
      /* Categories - Throbber and menu */ //#0C71D6
      var categories_hbox = new HBox (false, 0);

      menuthrobber = new MenuThrobber ();
      menuthrobber.set_state (StateType.SELECTED);
      menu = (MenuButton) menuthrobber;
      menuthrobber.set_size_request (14, 14);
      menuthrobber.button_scale = 0.75;

      categories_hbox.pack_start (flag_selector);
      categories_hbox.pack_start (menuthrobber, false);

      flag_selector.selected_markup = "<span size=\"small\"><b>%s</b></span>";
      flag_selector.unselected_markup = "<span size=\"x-small\">%s</span>";
      flag_selector.set_state (StateType.SELECTED);

      var hbox_panes = new HBox (false, 0);

      /* PANES */
      sp1 = new Label (null);
      sp2 = new Label (null);

      /* Source Pane */
      spane = new VBox (false, 0);
      spane.border_width = 5;
      spane.pack_start (source_icon, false);
      spane.pack_start (source_label, false);
      
      /* Action Pane */
      apane = new VBox (false, 0);
      apane.border_width = 5;
      apane.pack_start (action_icon, false);
      apane.pack_start (action_label, false);
      
      hbox_panes.pack_start (spane, false);
      hbox_panes.pack_start (sp1, true);
      hbox_panes.pack_start (apane, true);

      /* Target Pane */
      tpane = new VBox (false, 0);
      tpane.border_width = 5;
      tpane.pack_start (target_icon, false);
      tpane.pack_start (target_label, false);
      
      target_container = new VBox (false, 0);
      var hb = new HBox (false, 0);
      //hb.pack_start (sp2, false);
      hb.pack_start (tpane, false, false);
      var category_spacer = new SmartLabel ();
      category_spacer.size = SmartLabel.Size.SMALL;
      target_container.pack_start (category_spacer, false);
      target_container.pack_start (hb, false, true, 5);
      target_container.pack_start (new Label (null), true);

      /* list */
      spacer = new Label (null);
      spacer.set_size_request (1, SHADOW_SIZE + BORDER_RADIUS);
      this.prepare_results_container (out results_container, out results_sources,
                                      out results_actions, out results_targets);
      results_sources.set_state (StateType.SELECTED);
      results_actions.set_state (StateType.SELECTED);
      results_targets.set_state (StateType.SELECTED);

      container = new VBox (false, 0);
      container.pack_start (categories_hbox, false);
      container.pack_start (hbox_panes, false, true, 5);
      container.pack_start (description_label, false);
      container.pack_start (spacer, false);
      container.pack_start (results_container, false);
      
      var main_container = new HBox (false, 0);
      main_container.pack_start (container, false);
      main_container.pack_start (target_container, false);
      
      main_container.show_all ();
      results_container.hide ();
      
      this.add (main_container);
    }
    
    public override bool is_list_visible ()
    {
      return results_container.visible;
    }
    
    public override void set_list_visible (bool visible)
    {
      results_container.visible = visible;
    }
    
    public override void set_throbber_visible (bool visible)
    {
      menuthrobber.active = visible;
    }
    
    public override void update_searching_for ()
    {
      update_labels ();
      results_container.select_child (model.searching_for);
      queue_draw ();
    }
    
    public override void update_selected_category ()
    {
      flag_selector.selected = model.selected_category;
    }
    
    protected override void paint_background (Cairo.Context ctx)
    {
      bool comp = this.is_composited ();
      double r = 0, b = 0, g = 0;

      if (is_list_visible () || (!comp))
      {
        if (comp && is_list_visible ())
        {
          ctx.translate (0.5, 0.5);
          ctx.set_operator (Operator.OVER);
          Utils.cairo_make_shadow_for_rect (ctx, results_container.allocation.x,
                                                 results_container.allocation.y,
                                                 results_container.allocation.width - 1,
                                                 results_container.allocation.height - 1,
                                                 0, r, g, b, SHADOW_SIZE);
          ctx.translate (-0.5, -0.5);
        }
        ctx.set_operator (Operator.SOURCE);
        ch.set_source_rgba (ctx, 1.0, ch.StyleType.BASE, Gtk.StateType.NORMAL);
        ctx.rectangle (spacer.allocation.x, spacer.allocation.y + BORDER_RADIUS, spacer.allocation.width, SHADOW_SIZE);
        ctx.fill ();
      }

      int width = this.allocation.width;
      int height = spacer.allocation.y + BORDER_RADIUS + SHADOW_SIZE;
      
      // pattern
      Pattern pat = new Pattern.linear(0, 0, 0, height);
      r = g = b = 0.12;
      ch.get_color_colorized (ref r, ref g, ref b, ch.StyleType.BG, StateType.SELECTED);
      pat.add_color_stop_rgba (0.0, r, g, b, 0.95);
      r = g = b = 0.4;
      ch.get_color_colorized (ref r, ref g, ref b, ch.StyleType.BG, StateType.SELECTED);
      pat.add_color_stop_rgba (1.0, r, g, b, 1.0);
      
      r = g = b = 0.0;

      if (target_container.visible)
      {
        width -= target_container.allocation.width;
        // draw background
        ctx.save ();
        ctx.translate (0.5, 0.5);
        ctx.set_operator (Operator.OVER);
        Utils.cairo_make_shadow_for_rect (ctx, tpane.allocation.x - BORDER_RADIUS, 
                                               tpane.allocation.y,
                                               tpane.allocation.width - 1 + BORDER_RADIUS,
                                               tpane.allocation.height - 1, 15, r, g, b, SHADOW_SIZE);
        ctx.translate (-0.5, -0.5);
        Utils.cairo_rounded_rect (ctx, tpane.allocation.x - BORDER_RADIUS, 
                                       tpane.allocation.y,
                                       tpane.allocation.width + BORDER_RADIUS,
                                       tpane.allocation.height, 15);
        ctx.set_operator (Operator.SOURCE);
        ctx.set_source (pat);
        ctx.clip ();
        ctx.paint ();
        if (model.searching_for == SearchingFor.TARGETS)
        {
          ctx.set_operator (Cairo.Operator.OVER);
          Utils.cairo_rounded_rect (ctx, tpane.allocation.x,
                                         tpane.allocation.y,
                                         tpane.allocation.width,
                                         tpane.allocation.height,
                                         15);
          ch.set_source_rgba (ctx, 0.3,
                              ch.StyleType.FG, StateType.SELECTED);
          ctx.clip ();
          ctx.paint ();
        }
        ctx.restore ();
      }

      int delta = flag_selector.allocation.y - BORDER_RADIUS;
      if (!comp) delta = 0;
      
      ctx.save ();
      ctx.translate (SHADOW_SIZE, delta);
      width -= SHADOW_SIZE * 2;
      height -= SHADOW_SIZE + delta;
      // shadow
      ctx.translate (0.5, 0.5);
      ctx.set_operator (Operator.OVER);
      Utils.cairo_make_shadow_for_rect (ctx, 0, 0, width - 1, height - 1, BORDER_RADIUS, r, g, b, SHADOW_SIZE);
      ctx.translate (-0.5, -0.5);
      
      Utils.cairo_rounded_rect (ctx, 0, 0, width, height, BORDER_RADIUS);
      ctx.set_source (pat);
      ctx.set_operator (Operator.SOURCE);
      ctx.clip ();
      ctx.paint ();
      
      // reflection
      ctx.set_operator (Operator.OVER);
      ctx.new_path ();
      ctx.move_to (0, 0);
      ctx.rel_line_to (0.0, height / 3.0);
      ctx.rel_curve_to (width / 4.0, -height / 10.0, width / 4.0 * 3.0, -height / 10.0, width, 0.0);
      ctx.rel_line_to (0.0, -height / 3.0);
      ctx.close_path ();
      pat = new Pattern.linear (0, height / 10.0, 0, height / 3.0);
      ch.add_color_stop_rgba (pat, 0.0, 0.0, ch.StyleType.FG, StateType.SELECTED);
      ch.add_color_stop_rgba (pat, 0.7, 0.4, ch.StyleType.FG, StateType.SELECTED);
      ch.add_color_stop_rgba (pat, 1.0, 0.9, ch.StyleType.FG, StateType.SELECTED);
      ctx.set_source (pat);
      ctx.clip ();
      ctx.paint ();

      ctx.restore ();
      
      // icon bgs
      ctx.set_operator (Operator.OVER);
      ctx.save ();
      Utils.cairo_rounded_rect (ctx, spane.allocation.x,
                                     spane.allocation.y,
                                     spane.allocation.width,
                                     spane.allocation.height,
                                     15);
      ch.set_source_rgba (ctx, model.searching_for == SearchingFor.SOURCES ? 0.3 : 0.08,
                          ch.StyleType.FG, StateType.SELECTED);
      ctx.clip ();
      ctx.paint ();
      ctx.restore ();
      
      ctx.save ();
      Utils.cairo_rounded_rect (ctx, apane.allocation.x,
                                     apane.allocation.y,
                                     apane.allocation.width,
                                     apane.allocation.height,
                                     15);
      ch.set_source_rgba (ctx, model.searching_for == SearchingFor.ACTIONS ? 0.3 : 0.08,
                          ch.StyleType.FG, StateType.SELECTED);
      ctx.clip ();
      ctx.paint ();
      ctx.restore ();
    }
    
    private string get_down_to_see_recent ()
    {
      if (controller.DOWN_TO_SEE_RECENT == "") return controller.TYPE_TO_SEARCH;
      return "%s (%s)".printf (controller.TYPE_TO_SEARCH, controller.DOWN_TO_SEE_RECENT);
    }
    
    private void update_labels ()
    {
      var focus = model.get_actual_focus ();
      if (focus.value == null)
      {
        if (controller.is_in_initial_state ())
        {
          description_label.set_text (get_down_to_see_recent ());
        }
        else if (controller.is_searching_for_recent ())
        {
          description_label.set_text (controller.NO_RECENT_ACTIVITIES);
        }
        else
        {
          description_label.set_text (controller.NO_RESULTS);
        }
      }
      else
      {
        description_label.set_text (Utils.get_printable_description (focus.value));
      }
      if (model.searching_for == SearchingFor.TARGETS)
      {
        flag_selector.sensitive = false;
      }
      else
      {
        flag_selector.sensitive = true;
      }
      target_container.visible = model.needs_target ();
    }
    
    public override void update_focused_source (Entry<int, Match> m)
    {
      if (controller.is_in_initial_state ()) source_icon.set_icon_name ("search");
      else if (m.value == null) source_icon.set_icon_name ("");
      else
      {
        source_icon.set_icon_name (m.value.icon_name);
        results_sources.move_selection_to_index (m.key);
      }
      source_label.set_markup (Utils.markup_string_with_search (m.value == null ? "" : m.value.title, this.model.query[SearchingFor.SOURCES], ""));
      if (model.searching_for == SearchingFor.SOURCES) update_labels ();
    }
    
    public override void update_focused_action (Entry<int, Match> m)
    {
      if (controller.is_in_initial_state () ||
          model.focus[SearchingFor.SOURCES].value == null)
      {
        action_icon.clear ();
      }
      else if (m.value == null)
      {
        action_icon.set_icon_name ("");
      }
      else
      {
        action_icon.set_icon_name (m.value.icon_name);
        results_actions.move_selection_to_index (m.key);
      }
      action_label.set_markup (Utils.markup_string_with_search (m.value == null ? "" : m.value.title, this.model.query[SearchingFor.ACTIONS], ""));
      if (model.searching_for == SearchingFor.ACTIONS) update_labels ();
    }
    
    public override void update_focused_target (Entry<int, Match> m)
    {
      if (m.value == null) target_icon.set_icon_name ("");
      else
      {
        if (m.value is DefaultMatch)
          target_icon.set_icon_name ("text-plain");
        else
          target_icon.set_icon_name (m.value.icon_name);
        results_targets.move_selection_to_index (m.key);
      }
      target_label.set_markup (Utils.markup_string_with_search (m.value == null ? "" : m.value.title, this.model.query[SearchingFor.TARGETS], ""));
      if (model.searching_for == SearchingFor.TARGETS) update_labels ();
    }
    
    public override void update_sources (Gee.List<Match>? list = null)
    {
      results_sources.update_matches (list);
    }
    public override void update_actions (Gee.List<Match>? list = null)
    {
      results_actions.update_matches (list);
    }
    public override void update_targets (Gee.List<Match>? list = null)
    {
      results_targets.update_matches (list);
    }
  }
}
