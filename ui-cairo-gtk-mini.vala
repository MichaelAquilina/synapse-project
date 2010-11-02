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

    protected ResultBox result_box = null;
    protected Sezen.Throbber throbber = null;

    private const int UI_WIDTH = 600; // height is dynamic
    private const int PADDING = 8; // assinged to container_top's border width
    private const int SHADOW_SIZE = 8; // assigned to containers's border width in composited
    private const int SECTION_PADDING = 10;
    private const int BORDER_RADIUS = 10;
    private const int SELECTED_ICON_SIZE = 160;
    private const int UNSELECTED_ICON_SIZE = SELECTED_ICON_SIZE / 3;
    private const int LABEL_INTERNAL_PADDING = 3;
    
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
/*
      window.key_press_event.connect (key_press_event);

      set_list_visible (false); */
      
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
      window.add (container);
      
      container_top = new HBox (false, 0);
      container_top.border_width = BORDER_RADIUS;
      container.add (container_top);
      
      /* Match Icon packed into container_top */
      match_icon_container_overlayed = new ContainerOverlayed();
      match_icon_thumb = new NamedIcon();
      match_icon_thumb.set_pixel_size (SELECTED_ICON_SIZE / 2);
      match_icon_thumb.set_size_request (SELECTED_ICON_SIZE / 2, SELECTED_ICON_SIZE / 2);
      match_icon = new NamedIcon ();
      match_icon.set_size_request (SELECTED_ICON_SIZE, SELECTED_ICON_SIZE);
      match_icon.set_pixel_size (SELECTED_ICON_SIZE);
      match_icon_container_overlayed.main = match_icon;
      match_icon_container_overlayed.overlay = match_icon_thumb;
      container_top.pack_start (match_icon_container_overlayed, false, true, SECTION_PADDING);
      
      /* Action Icon packed into container_top */
      action_icon = new NamedIcon ();
      action_icon.set_pixel_size (UNSELECTED_ICON_SIZE);
      action_icon.set_alignment (0.5f, 0.5f);
      action_icon.set_size_request (UNSELECTED_ICON_SIZE, UNSELECTED_ICON_SIZE);
      action_icon.sensitive = false;
      container_top.pack_start (action_icon, false, true, SECTION_PADDING);
      
      /* Match or Action Label */
      current_label = new FakeInput ();
      current_label.xpad = LABEL_INTERNAL_PADDING * 2;
      current_label.ypad = LABEL_INTERNAL_PADDING;
      current_label.set_alignment (0.0f, 0.5f);
      
      /* Query flag selector  */
      flag_selector = new HSelectionContainer(_hilight_label, 15);
      foreach (string s in this.categories)
        flag_selector.add (new Label(s));
      flag_selector.select (3);
      
      var vbox = new VBox (false, 0);
      vbox.pack_start (new Label(null));
      vbox.pack_start (flag_selector, false);
      vbox.pack_start (current_label, false);
      vbox.pack_start (new Label(null));
      container_top.pack_start (vbox, true, true, SECTION_PADDING);
      
      //DEBUG
      container.border_width = SHADOW_SIZE;
      match_icon.set_icon_name ("search", IconSize.DIALOG);
      action_icon.set_icon_name ("system-run", IconSize.DIALOG);
      current_label.set_markup (Utils.markup_string_with_search ("match.title", "title", "x-large"));
      
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
    }
    public bool expose_event (Widget widget, Gdk.EventExpose event)
    {
      bool comp = widget.is_composited ();
      var ctx = Gdk.cairo_create (widget.get_window ());
      ctx.set_operator (Operator.CLEAR);
      ctx.paint ();
      ctx.set_operator (Operator.OVER);
      Gtk.Style style = widget.get_style();
      double r = 0.0, g = 0.0, b = 0.0;
      double x = this.container.border_width,
             y = flag_selector.allocation.y - BORDER_RADIUS;
      double w = UI_WIDTH - this.container.border_width * 2,
             h = current_label.allocation.y - y + current_label.allocation.height + BORDER_RADIUS;
      if (comp)
      {
        //draw shadow
        Utils.gdk_color_to_rgb (style.bg[Gtk.StateType.NORMAL], &r, &g, &b);
        Utils.rgb_invert_color (out r, out g, out b);
        Utils.cairo_make_shadow_for_rect (ctx, x, y, w, h, BORDER_RADIUS,
                                          r, g, b, 0.9, SHADOW_SIZE);
      }
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
                                  0.98);
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
          set_match_search (s);
        else
          set_action_search (s);
      }
    }
    protected virtual bool key_press_event (Gdk.EventKey event)
    {
      if (im_context.filter_keypress (event)) return true;

      uint key = event.keyval;
      switch (key)
      {
        
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

    }
    protected override void focus_action ( int index, Match? action )
    {
      
    }
    protected override void update_match_result_list (Gee.List<Match>? matches, int index, Match? match)
    {

    }
    protected override void update_action_result_list (Gee.List<Match>? actions, int index, Match? action)
    {

    }
  }
}
