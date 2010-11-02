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
  public class SezenWindowMini : UIInterface
  {
    Window window;
    bool searching_for_matches = true;
    
    /* Main UI shared components */
    protected NamedIcon match_icon = null;
    protected NamedIcon match_icon_thumb = null;
    protected NamedIcon action_icon = null;
    protected ContainerOverlayed match_icon_container_overlayed = null;
    
    protected Label match_label_description = null;
    protected FakeInput current_label = null;

    protected HSelectionContainer flag_selector = null;
    protected HBox container_top = null;
    protected VBox container = null;
    
    protected HSelectionContainer results_container = null;

    protected ResultBox results_match = null;
    protected ResultBox results_action = null;
    
    protected Sezen.Throbber throbber = null;

    private const int UI_WIDTH = 600; // height is dynamic
    private const int PADDING = 8; // assinged to container_top's border width
    private const int SHADOW_SIZE = 8; // assigned to containers's border width in composited
    private const int SECTION_PADDING = 10;
    private const int BORDER_RADIUS = 10;
    private const int ICON_SIZE = 160;
    private const int TOP_SPACING = ICON_SIZE / 4;
    private const int LABEL_INTERNAL_PADDING = 3;
    private const string LABEL_TEXT_SIZE = "x-large";
    
    private string[] categories = {"Actions", "Audio", "Applications", "All", "Documents", "Images", "Video", "Internet"};
    private QueryFlags[] categories_query = {QueryFlags.ACTIONS, QueryFlags.AUDIO, QueryFlags.APPLICATIONS, QueryFlags.ALL,
                                             QueryFlags.DOCUMENTS, QueryFlags.IMAGES, QueryFlags.VIDEO, QueryFlags.INTERNET};

    /* STATUS */
    private bool list_visible = true;
    private IMContext im_context;
    
    public SezenWindowMini ()
    {
      window = new Window ();
      window.skip_taskbar_hint = true;
      window.skip_pager_hint = true;
      window.set_position (WindowPosition.CENTER);
      window.set_decorated (false);
      window.set_resizable (false);
      
      build_ui ();

      Utils.ensure_transparent_bg (window);
      window.expose_event.connect (expose_event);
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
      /* containers holds top hbox and result list */
      container = new VBox (false, 0);
      container.set_size_request (UI_WIDTH, -1);
      container.border_width = SHADOW_SIZE;
      window.add (container);
      
      container_top = new HBox (false, 0);
      container_top.border_width = BORDER_RADIUS;
      container.pack_start (container_top, false);
      
      results_container = new HSelectionContainer (null, 0);
      results_container.set_separator_visible (false);
      container.pack_start (results_container, false);
      
      results_match = new ResultBox (UI_WIDTH - SHADOW_SIZE * 2 - 2);
      results_action = new ResultBox (UI_WIDTH - SHADOW_SIZE * 2 - 2);
      results_container.add (results_match);
      results_container.add (results_action);

      throbber = new Throbber ();
      throbber.set_size_request (22, 22);
      
      /* Action Icon */
      action_icon = new NamedIcon ();
      action_icon.set_pixel_size (ICON_SIZE * 29 / 100);
      action_icon.set_alignment (0.5f, 0.5f);
      /* Match Icon packed into container_top */
      match_icon_container_overlayed = new ContainerOverlayed();
      match_icon_thumb = new NamedIcon();
      match_icon_thumb.set_pixel_size (ICON_SIZE / 2);
      match_icon = new NamedIcon ();
      match_icon.set_pixel_size (ICON_SIZE);
      match_icon_container_overlayed.set_size_request (ICON_SIZE, ICON_SIZE);
      match_icon_container_overlayed.set_scale_for_pos (0.3f, ContainerOverlayed.Position.BOTTOM_RIGHT);
      match_icon_container_overlayed.set_widget_in_position 
            (match_icon, ContainerOverlayed.Position.MAIN);
      match_icon_container_overlayed.set_widget_in_position 
            (match_icon_thumb, ContainerOverlayed.Position.BOTTOM_LEFT);
      match_icon_container_overlayed.set_widget_in_position 
            (action_icon, ContainerOverlayed.Position.BOTTOM_RIGHT);
      container_top.pack_start (match_icon_container_overlayed, false, true, SECTION_PADDING);
      
      
      //container_top.pack_start (action_icon, false, true, SECTION_PADDING);
      
      /* Match or Action Label */
      current_label = new FakeInput ();
      current_label.xpad = LABEL_INTERNAL_PADDING * 2;
      current_label.ypad = LABEL_INTERNAL_PADDING;
      current_label.set_alignment (0.0f, 1.0f);
      current_label.set_ellipsize (Pango.EllipsizeMode.END);
      
      /* Query flag selector  */
      flag_selector = new HSelectionContainer(_hilight_label, 15);
      foreach (string s in this.categories)
        flag_selector.add (new Label(s));
      flag_selector.select (3);
      
      var vbox = new VBox (false, 0);
      var spacer = new Label (null);
      spacer.set_size_request (-1, TOP_SPACING);
      vbox.pack_start (spacer);
      vbox.pack_start (new Label(null));
      vbox.pack_start (flag_selector, false);
      vbox.pack_start (current_label, false);
      vbox.pack_start (new Label(null));
      container_top.pack_start (vbox, true, true, SECTION_PADDING);
      
      container.show_all ();
    }
    
    private void set_list_visible (bool b)
    {
      if (b == list_visible)
        return;
      list_visible = b;
      results_container.visible = b;
      window.queue_draw ();
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
    }
    public bool expose_event (Widget widget, Gdk.EventExpose event)
    {
      bool comp = widget.is_composited ();
      var ctx = Gdk.cairo_create (widget.get_window ());
      ctx.set_operator (Operator.CLEAR);
      ctx.paint ();
      Gtk.Style style = widget.get_style();
      double r = 0.0, g = 0.0, b = 0.0;
      double x = this.container.border_width,
             y = flag_selector.allocation.y - BORDER_RADIUS;
      double w = UI_WIDTH - this.container.border_width * 2,
             h = current_label.allocation.y - y + current_label.allocation.height + BORDER_RADIUS;
      ctx.set_operator (Operator.OVER);
      if (list_visible)
      {
        double ly = y + h - BORDER_RADIUS;
        double lh = results_container.allocation.y - ly + results_container.allocation.height;
        ctx.rectangle (x, ly, w, lh);
        ctx.set_source_rgba (1, 1, 1, 1);
        ctx.fill ();
        Utils.gdk_color_to_rgb (style.bg[Gtk.StateType.NORMAL], &r, &g, &b);
        Utils.rgb_invert_color (out r, out g, out b);
        if (comp)
        {
          //draw shadow
          Utils.cairo_make_shadow_for_rect (ctx, x, ly, w, lh, 0,
                                            r, g, b, 0.9, SHADOW_SIZE);
        }
      }
      if (comp)
      {
        //draw shadow
        Utils.gdk_color_to_rgb (style.bg[Gtk.StateType.NORMAL], &r, &g, &b);
        Utils.rgb_invert_color (out r, out g, out b);
        Utils.cairo_make_shadow_for_rect (ctx, x, y, w, h, BORDER_RADIUS,
                                          r, g, b, 0.9, SHADOW_SIZE);
      }
      ctx.set_operator (Operator.OVER);
      Pattern pat = new Pattern.linear(0, flag_selector.allocation.y - BORDER_RADIUS, 0,
                                          current_label.allocation.y + BORDER_RADIUS);
      Utils.gdk_color_to_rgb (style.bg[Gtk.StateType.NORMAL], &r, &g, &b);
      pat.add_color_stop_rgba (0, double.min(r + 0.15, 1),
                                  double.min(g + 0.15, 1),
                                  double.min(b + 0.15, 1),
                                  0.98);
      pat.add_color_stop_rgba (1, double.max(r - 0.15, 0),
                                  double.max(g - 0.15, 0),
                                  double.max(b - 0.15, 0),
                                  1.0);
      Utils.cairo_rounded_rect (ctx, x, y, w, h, BORDER_RADIUS);
      ctx.set_source (pat);
      ctx.fill ();

      Bin c = (widget is Bin) ? (Bin) widget : null;
      if (c != null)
        c.propagate_expose (c.get_child(), event);
      return true;
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
        {
          set_match_search (s);
          if (s == "")
            set_list_visible (false);
        }
        else
          set_action_search (s);
      }
    }
    private void visual_update_search_for ()
    {
      if (searching_for_matches)
      {
        action_icon.set_pixel_size (ICON_SIZE * 29 / 100);
        match_icon.set_pixel_size (ICON_SIZE);
        match_icon_container_overlayed.swapif (action_icon,
                                               ContainerOverlayed.Position.MAIN,
                                               ContainerOverlayed.Position.BOTTOM_RIGHT);
        results_container.select (0);
      }
      else
      {
        match_icon.set_pixel_size (ICON_SIZE * 29 / 100);
        action_icon.set_pixel_size (ICON_SIZE);
        match_icon_container_overlayed.swapif (match_icon,
                                               ContainerOverlayed.Position.MAIN,
                                               ContainerOverlayed.Position.BOTTOM_RIGHT);
        results_container.select (1);
      }
    }
    private void hide_and_reset ()
    {
      window.hide ();
      set_list_visible (false);
      flag_selector.select (3);
      searching_for_matches = true;
      visual_update_search_for ();
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
            visual_update_search_for ();
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
            visual_update_search_for ();
            window.queue_draw ();
          }
          update_query_flags (this.categories_query[flag_selector.get_selected()]);
          break;
        case Gdk.KeySyms.Right:
          flag_selector.select_next ();
          if (!searching_for_matches)
          {
            searching_for_matches = true;
            visual_update_search_for ();
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
          visual_update_search_for ();
          break;
        default:
          //debug ("im_context didn't filter...");
          break;
      }
      return true;
    }

    /* UI INTERFACE IMPLEMENTATION */
    public override void show ()
    {
      window.show ();
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
      if (match == null)
      {
        /* Show default stuff */
        if (get_match_search () != "")
        {
          if (searching_for_matches)
           current_label.set_markup (Utils.markup_string_with_search ("", get_match_search (), LABEL_TEXT_SIZE));

          match_icon.set_icon_name ("search", IconSize.DIALOG);
          match_icon_thumb.clear ();
        }
        else
        {
          if (searching_for_matches)
            current_label.set_markup (
            Markup.printf_escaped ("<span size=\"%s\">%s</span>", LABEL_TEXT_SIZE,
                                   "Type to search..."));
          match_icon.set_icon_name ("search", IconSize.DIALOG);
          match_icon_thumb.clear ();
        }
      }
      else
      {
        match_icon.set_icon_name (match.icon_name, IconSize.DIALOG);
        if (match.has_thumbnail)
          match_icon_thumb.set_icon_name (match.thumbnail_path, IconSize.DIALOG);
        else
          match_icon_thumb.clear ();

        if (searching_for_matches)
          current_label.set_markup (Utils.markup_string_with_search (match.title, get_match_search (), LABEL_TEXT_SIZE));
      }
      results_match.move_selection_to_index (index);
    }
    protected override void focus_action ( int index, Match? action )
    {
      if (action == null)
      {
        action_icon.hide ();
        action_icon.set_icon_name ("system-run", IconSize.DIALOG);
        if (!searching_for_matches)
          current_label.set_markup (Utils.markup_string_with_search ("", get_action_search(), LABEL_TEXT_SIZE));
      }
      else
      {
        action_icon.show ();
        action_icon.set_icon_name (action.icon_name, IconSize.DIALOG);
        if (!searching_for_matches)
          current_label.set_markup (Utils.markup_string_with_search (action.title, get_action_search (), LABEL_TEXT_SIZE));
      }
      results_action.move_selection_to_index (index);
    }
    protected override void update_match_result_list (Gee.List<Match>? matches, int index, Match? match)
    {
      results_match.update_matches (matches);
      focus_match ( index, match );
    }
    protected override void update_action_result_list (Gee.List<Match>? actions, int index, Match? action)
    {
      results_action.update_matches (actions);
      focus_action ( index, action );
    }
  }
}
