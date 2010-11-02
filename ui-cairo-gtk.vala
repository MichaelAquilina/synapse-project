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
 * Authored by Alberto Aldegheri <albyrock87+dev@gmail.com>
 *             Michal Hruby <michal.mhr@gmail.com>
 *
 */

using Gtk;
using Cairo;
using Gee;

namespace Sezen
{
  public class SezenWindow : UIInterface
  {
    Window window;
    /* Main UI shared components */
    protected NamedIcon match_icon = null;
    protected NamedIcon match_icon_thumb = null;
    protected ShrinkingLabel match_label = null;
    protected Label match_label_description = null;
    protected NamedIcon action_icon = null;
    protected Label action_label = null;
    protected HSelectionContainer flag_selector = null;
    protected HBox top_hbox = null;
    protected Label top_spacer = null;
    protected VBox container = null;
    protected VBox container_top = null;
    protected ContainerOverlayed match_icon_container_overlayed = null;
    protected ResultBox result_box = null;
    protected Sezen.Throbber throbber = null;

    private const int UI_WIDTH = 600; // height is dynamic
    private const int PADDING = 8; // assinged to container_top's border width
    private const int SHADOW_SIZE = 12; // assigned to containers's border width in composited
    private const int BORDER_RADIUS = 20;
    private const int ICON_SIZE = 172;
    private const int ACTION_ICON_SIZE = 48;
    
    private string[] categories = {"Actions", "Audio", "Applications", "All", "Documents", "Images", "Video", "Internet"};
    private QueryFlags[] categories_query = {QueryFlags.ACTIONS, QueryFlags.AUDIO, QueryFlags.APPLICATIONS, QueryFlags.ALL,
                                             QueryFlags.DOCUMENTS, QueryFlags.IMAGES, QueryFlags.VIDEO, QueryFlags.INTERNET};

    /* STATUS */
    private bool list_visible = true;
    private IMContext im_context;
    
    public SezenWindow ()
    {
      window = new Window ();
      window.skip_taskbar_hint = true;
      window.skip_pager_hint = true;
      window.set_position (WindowPosition.CENTER);
      window.set_decorated (false);
      window.set_resizable (false);
      
      build_ui ();

      Utils.ensure_transparent_bg (window);
      window.expose_event.connect (on_expose);
      on_composited_changed (window);
      window.composited_changed.connect (on_composited_changed);

      window.key_press_event.connect (key_press_event);

      set_list_visible (false);
      
      /* SEZEN */
      focus_match (0, null);
      focus_action (0, null);

      im_context = new IMMulticontext ();
      im_context.set_use_preedit (false);
      im_context.commit.connect (search_add_char);
      im_context.focus_in ();
      
      window.key_press_event.connect (key_press_event);
    }

    protected virtual void build_ui ()
    {
      container = new VBox (false, 0);
      window.add (container);

      /* ==> Top container */
      container_top = new VBox (false, 0);
      container_top.set_size_request (UI_WIDTH, -1);
      container_top.border_width = PADDING;
      /* ==> Result box */
      result_box = new ResultBox (400, 5);
      var hbox_result_box = new HBox (true, 0);
      hbox_result_box.pack_start (result_box,false,false);
      /* <== Pack */
      container.pack_start (container_top);
      container.pack_start (hbox_result_box,false);

      /* Top Hbox */
      top_hbox = new HBox (false, 0);
      /* Match Description */
      match_label_description = new Label (null);
      match_label_description.set_alignment (0, 0);
      match_label_description.set_ellipsize (Pango.EllipsizeMode.END); 
      match_label_description.set_line_wrap (true);
      /* Packing Top Hbox with Match Desctiption into Top VBox*/
      container_top.pack_start (top_hbox);
      container_top.pack_start (match_label_description, false);
      
      /* Match Icon packed into Top HBox */
      match_icon_container_overlayed = new ContainerOverlayed();
      match_icon_thumb = new NamedIcon();
      match_icon_thumb.set_pixel_size (ICON_SIZE / 2);
      match_icon = new NamedIcon ();
      match_icon.set_size_request (ICON_SIZE, ICON_SIZE);
      match_icon.set_pixel_size (ICON_SIZE);
      match_icon_container_overlayed.set_widget_in_position 
            (match_icon, ContainerOverlayed.Position.MAIN);
      match_icon_container_overlayed.set_widget_in_position 
            (match_icon_thumb, ContainerOverlayed.Position.BOTTOM_LEFT);
      top_hbox.pack_start (match_icon_container_overlayed, false);
      
      /* VBox to push down the right area */
      var top_right_vbox = new VBox (false, 0);
      top_hbox.pack_start (top_right_vbox);
      /* Top Spacer */
      top_spacer = new Label(null);
      /* flag_selector */
      flag_selector = new HSelectionContainer(_hilight_label, 15);
      foreach (string s in this.categories)
        flag_selector.add (new Label(s));
      flag_selector.select (3);
      /* Throbber */
      throbber = new Sezen.Throbber ();
      throbber.set_size_request (20, -1);
      /* HBox for titles and action icon */
      var right_hbox = new HBox (false, 0);
      /* HBox for throbber and flag_selector */
      var topright_hbox = new HBox (false, 0);
      
      topright_hbox.pack_start (flag_selector);
      topright_hbox.pack_start (throbber, false);

      top_right_vbox.pack_start (top_spacer, true);
      top_right_vbox.pack_start (topright_hbox, false);
      top_right_vbox.pack_start (right_hbox, false);
      
      /* Titles box and Action icon*/
      var labels_hbox = new HBox (false, 0);
      action_icon = new NamedIcon ();
      action_icon.set_pixel_size (ACTION_ICON_SIZE);
      action_icon.set_alignment (0.5f, 0.5f);
      action_icon.set_size_request (ACTION_ICON_SIZE, ACTION_ICON_SIZE);

      right_hbox.pack_start (labels_hbox);
      right_hbox.pack_start (action_icon, false);
      
      match_label = new ShrinkingLabel ();
      match_label.set_alignment (0.0f, 0.5f);
      match_label.set_ellipsize (Pango.EllipsizeMode.END);
      match_label.xpad = 10;

      action_label = new Label (null);
      action_label.set_alignment (1.0f, 0.5f);
      //action_label.set_ellipsize (Pango.EllipsizeMode.START);
      action_label.xpad = 10;
      
      labels_hbox.pack_start (match_label);
      labels_hbox.pack_start (action_label, false);

      container.show_all ();
    }
    
    protected virtual void on_composited_changed (Widget w)
    {
      Gdk.Screen screen = w.get_screen ();
      bool comp = screen.is_composited ();
      Gdk.Colormap? cm = screen.get_rgba_colormap();
      if (cm == null)
      {
        comp = false;
        cm = screen.get_rgb_colormap();
      }
      debug ("Screen is%s composited.", comp?"": " NOT");
      w.set_colormap (cm);
      if (comp)
        container.border_width = SHADOW_SIZE;
      else
        container.border_width = 2;
      this.hide_and_reset ();
    }
    
    protected virtual void set_input_mask ()
    {
      Requisition req = {0, 0};
      window.size_request (out req);
      int w = req.width, h = req.height;
      bool composited = window.is_composited ();
      var bitmap = new Gdk.Pixmap (null, w, h, 1);
      var ctx = Gdk.cairo_create (bitmap);
      ctx.set_operator (Cairo.Operator.CLEAR);
      ctx.paint ();
      ctx.set_source_rgba (0, 0, 0, 1);
      ctx.set_operator (Cairo.Operator.SOURCE);
      if (composited)
      {
        int spacing = top_spacer.allocation.height;
        Utils.cairo_rounded_rect (ctx, SHADOW_SIZE, SHADOW_SIZE,
                                       ICON_SIZE + PADDING * 2,
                                       ICON_SIZE, BORDER_RADIUS);
        ctx.fill ();
        Utils.cairo_rounded_rect (ctx, 0, spacing,
                                       container_top.allocation.width + SHADOW_SIZE * 2, 
                                       container_top.allocation.height + SHADOW_SIZE * 2 - spacing,
                                       BORDER_RADIUS);
        ctx.fill ();
        if (list_visible)
        {
          result_box.size_request (out req);
              
          ctx.rectangle ((w - req.width) / 2,
                         container_top.allocation.height,
                         req.width,
                         h - container_top.allocation.height);
          ctx.fill ();
        }
      }
      else
      {
        ctx.set_operator (Cairo.Operator.SOURCE);
        ctx.paint ();
      }
      window.input_shape_combine_mask (null, 0, 0);
      window.input_shape_combine_mask ((Gdk.Bitmap*)bitmap, 0, 0);
    }
    
    protected virtual bool on_expose (Widget widget, Gdk.EventExpose event) {
      bool comp = widget.is_composited ();
      var ctx = Gdk.cairo_create (widget.window);
      ctx.set_operator (Operator.CLEAR);
      ctx.paint ();
      ctx.set_operator (Operator.OVER);
      double w = container_top.allocation.width;
      double h = container_top.allocation.height;
      double x = container_top.allocation.x;
      double y = container_top.allocation.y;
      Gtk.Style style = widget.get_style();
      double r = 0.0, g = 0.0, b = 0.0;
      if (comp)
      {
        int spacing = top_spacer.allocation.height;
        y += spacing;
        h -= spacing;
        //draw shadow
        Utils.gdk_color_to_rgb (style.bg[Gtk.StateType.NORMAL], &r, &g, &b);
        Utils.rgb_invert_color (out r, out g, out b);
        Utils.cairo_make_shadow_for_rect (ctx, x, y, w, h, BORDER_RADIUS,
                                          r, g, b, 0.9, SHADOW_SIZE);
        // border
        _cairo_path_for_main (ctx, comp, x + 0.5, y + 0.5, w - 1, h - 1);
        ctx.set_source_rgba (r, g, b, 0.9);
        ctx.set_line_width (2.5);
        ctx.stroke ();
        if (this.list_visible)
        {
          //draw shadow
          Utils.cairo_make_shadow_for_rect (ctx, result_box.allocation.x,
                                                 result_box.allocation.y,
                                                 result_box.allocation.width,
                                                 result_box.allocation.height,
                                                 0, r, g, b, 0.9, SHADOW_SIZE);
          ctx.rectangle (result_box.allocation.x,
                         result_box.allocation.y,
                         result_box.allocation.width,
                         result_box.allocation.height);
          ctx.set_source_rgba (r, g, b, 0.9);
          ctx.set_line_width (2.5);
          ctx.stroke ();
        }
      }
      Pattern pat = new Pattern.linear(0, y, 0, y+h);
      Utils.gdk_color_to_rgb (style.bg[Gtk.StateType.NORMAL], &r, &g, &b);
      pat.add_color_stop_rgba (0, double.min(r + 0.15, 1),
                                  double.min(g + 0.15, 1),
                                  double.min(b + 0.15, 1),
                                  0.95);
      pat.add_color_stop_rgba (1, double.max(r - 0.15, 0),
                                  double.max(g - 0.15, 0),
                                  double.max(b - 0.15, 0),
                                  0.95);

      _cairo_path_for_main (ctx, comp, x, y, w, h);
      ctx.set_source (pat);
      ctx.set_operator (Operator.SOURCE);
      ctx.fill ();
      ctx.set_operator (Operator.OVER);
      if (!comp)
      {
        Utils.rgb_invert_color (out r, out g, out b);
        _cairo_path_for_main (ctx, comp, x, y, w, h);
        ctx.set_source_rgba (r, g, b, 1.0);
        ctx.set_line_width (3.5);
        ctx.stroke (); 
      }
      /* Propagate Expose */               
      Bin c = (widget is Bin) ? (Bin) widget : null;
      if (c != null)
        c.propagate_expose (c.get_child(), event);
      return true;
    }

    private void _cairo_path_for_main (Cairo.Context ctx, bool composited,
                                       double x, double y, double w, double h)
    {
      

      if (composited)
        Utils.cairo_rounded_rect (ctx, x, y, w, h, BORDER_RADIUS);
      else
      {
        w = container.allocation.width;
        h = container.allocation.height;
        x = container.allocation.x;
        y = container.allocation.y;
        ctx.rectangle (x, y, w, h);
      }
    }

    private static void _hilight_label (Widget w, bool b)
    {
      Label l = (Label) w;
      if (b)
      {
        string s = l.get_text();
        l.set_markup (Markup.printf_escaped ("<span size=\"large\"><b>%s</b></span>", s));
        l.sensitive = true;
      }
      else
      {
        string s = l.get_text();
        l.set_markup (Markup.printf_escaped ("<span size=\"small\">%s</span>", s));
        l.sensitive = false;
      }
    }
    bool searching_for_matches = true;
    
    /* EVENTS HANDLING HERE */
    private void search_add_char (string chr)
    {
      if (searching_for_matches)
        set_match_search (get_match_search() + chr);
      else
        set_action_search (get_action_search() + chr);
    }
    private void search_delete_char ()
    {
      string s = "";
      if (searching_for_matches)
        s = get_match_search ();
      else
        s = get_action_search ();
      long len = s.length;
      if (len > 0)
      {
        s = s.substring (0, len - 1);
        if (searching_for_matches)
          set_match_search (s);
        else
          set_action_search (s);
      }
    }

    private void hide_and_reset ()
    {
      window.hide ();
      set_list_visible (false);
      flag_selector.select (3);
      searching_for_matches = true;
      reset_search ();
    }
    
    protected virtual bool key_press_event (Gdk.EventKey event)
    {
      if (im_context.filter_keypress (event)) return true;

      uint key = event.keyval;
      switch (key)
      {
        case Gdk.KeySyms.Return:
        case Gdk.KeySyms.KP_Enter:
        case Gdk.KeySyms.ISO_Enter:
          if (execute ())
            hide_and_reset ();
          break;
        case Gdk.KeySyms.Delete:
        case Gdk.KeySyms.BackSpace:
          search_delete_char ();
          break;
        case Gdk.KeySyms.Escape:
          if (!searching_for_matches)
          {
            set_action_search ("");
            searching_for_matches = true;
            window.queue_draw ();
          }
          else if (get_match_search() != "")
          {
            set_match_search("");
            set_list_visible (false);
          }
          else
          {
            hide_and_reset ();
          }
          break;
        case Gdk.KeySyms.Left:
          flag_selector.select_prev ();
          if (!searching_for_matches)
          {
            searching_for_matches = true;
            window.queue_draw ();
          }
          update_query_flags (this.categories_query[flag_selector.get_selected()]);
          break;
        case Gdk.KeySyms.Right:
          flag_selector.select_next ();
          if (!searching_for_matches)
          {
            searching_for_matches = true;
            window.queue_draw ();
          }
          update_query_flags (this.categories_query[flag_selector.get_selected()]);
          break;
        case Gdk.KeySyms.Up:
          bool b = true;
          if (searching_for_matches)
            b = select_prev_match ();
          else
            b = select_prev_action ();
          if (!b)
            set_list_visible (false);
          break;
        case Gdk.KeySyms.Down:
          if (!list_visible)
          {
            set_list_visible (true);
            return true;
          }
          if (searching_for_matches)
            select_next_match ();
          else
            select_next_action ();
          set_list_visible (true);
          break;
        case Gdk.KeySyms.Tab:
          if (searching_for_matches && 
              (get_match_results () == null || get_match_results ().size == 0 ||
               get_action_results () == null || get_action_results ().size == 0))
            return true;
          searching_for_matches = !searching_for_matches;
          Match m = null;
          int i = 0;
          if (searching_for_matches)
          {
            get_match_focus (out i, out m);
            update_match_result_list (get_match_results (), i, m);
            get_action_focus (out i, out m);
            focus_action (i, m);
          }
          else
          {
            get_match_focus (out i, out m);
            focus_match (i, m); 
            get_action_focus (out i, out m);
            update_action_result_list (get_action_results (), i, m);
          }
          window.queue_draw ();
          break;
        default:
          //debug ("im_context didn't filter...");
          break;
      }

      return true;
    }
    private void set_list_visible (bool b)
    {
      if (b==this.list_visible)
        return;
      this.list_visible = b;
      if (b)
      {
        result_box.show();
      }
      else
      {
        result_box.hide();
      }
      window.queue_draw ();
      set_input_mask ();
    }   
    
    private string get_description_markup (string s)
    {
      // FIXME: i18n
      return Markup.printf_escaped ("<span size=\"medium\">%s</span>", Utils.replace_home_path_with (s, "Home > "));
    }
    
    /* UI INTERFACE IMPLEMENTATION */
    public override void show ()
    {
      window.show ();
      set_input_mask ();
    }
    public override void hide ()
    {
      window.hide ();
    }
    public override void present_with_time (uint32 timestamp)
    {
      window.present_with_time (timestamp);
    }    
    protected override void set_throbber_visible (bool visible)
    {
      if (visible)
        throbber.start ();
      else
        throbber.stop ();
    }
    protected override void focus_match ( int index, Match? match )
    {
      string size = searching_for_matches ? "xx-large": "medium";
      if (match == null)
      {
        /* Show default stuff */
        if (get_match_search () != "")
        {
          match_label.set_markup (Utils.markup_string_with_search ("", get_match_search (), size));
          match_label_description.set_markup (
            get_description_markup (throbber.is_animating ()? "Searching..." : "Match not found.")
          );
          match_icon.set_icon_name ("search", IconSize.DIALOG);
          match_icon_thumb.clear ();
        }
        else
        {
          match_icon.set_icon_name ("search", IconSize.DIALOG);
          match_icon_thumb.clear ();
          match_label.set_markup (
            Markup.printf_escaped ("<span size=\"xx-large\">%s</span>",
                                   "Type to search..."));
          match_label_description.set_markup (
            Markup.printf_escaped ("<span size=\"medium\"> </span>" +
                                   "<span size=\"smaller\">%s</span>",
                                   "Powered by Zeitgeist"));
        }
      }
      else
      {
        match_icon.set_icon_name (match.icon_name, IconSize.DIALOG);
        if (match.has_thumbnail)
          match_icon_thumb.set_icon_name (match.thumbnail_path, IconSize.DIALOG);
        else
          match_icon_thumb.clear ();

        match_label.set_markup (Utils.markup_string_with_search (match.title, get_match_search (), size));
        match_label_description.set_markup (get_description_markup (match.description));
        if (searching_for_matches)
        {
          result_box.move_selection_to_index (index);
        }
      }
    }
    protected override void focus_action ( int index, Match? action )
    {
      string size = !searching_for_matches ? "xx-large": "medium";
      if (action == null)
      {
        action_icon.set_sensitive (false);
        action_icon.set_icon_name ("system-run", IconSize.DIALOG);
        action_label.set_markup (Utils.markup_string_with_search ("", get_action_search(), size));
      }
      else
      {
        action_icon.set_sensitive (true);
        action_icon.set_icon_name (action.icon_name, IconSize.DIALOG);
        action_label.set_markup (Utils.markup_string_with_search (action.title,
                                 searching_for_matches ? 
                                 "" : get_action_search (), size));
        if (!searching_for_matches)
        {
          result_box.move_selection_to_index (index);
        }
      }
    }
    protected override void update_match_result_list (Gee.List<Match>? matches, int index, Match? match)
    {
      if (searching_for_matches)
      {
        result_box.update_matches (matches);
        if (matches == null || matches.size == 0)
          set_list_visible (false);
      }
      focus_match ( index, match );
    }
    protected override void update_action_result_list (Gee.List<Match>? actions, int index, Match? action)
    {
      if (!searching_for_matches)
      {
        result_box.update_matches (actions);
        if (actions == null || actions.size == 0)
          set_list_visible (false);
      }
      focus_action (index, action);
    }
  }
}
