# MonArch - Groundwork Monitor Architect
# MonarchForms.pm
#
############################################################################
# Release 4.6
# November 2017
############################################################################
#
# Original author: Scott Parris
#
# Copyright 2007-2017 GroundWork Open Source, Inc. (GroundWork)
# All rights reserved. This program is free software; you can redistribute
# it and/or modify it under the terms of the GNU General Public License
# version 2 as published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
#

use strict;
use MonarchInstrument;

package Forms;

my $cgi_exe = 'monarch.cgi';

my $SERVER_SOFTWARE = $ENV{SERVER_SOFTWARE};

my $monarch_cgi;
my $monarch_css;
my $monarch_html;
my $monarch_images;
my $monarch_js;
my $monarch_download;
my $monarch_export;
if (defined($SERVER_SOFTWARE) && $SERVER_SOFTWARE eq 'TOMCAT') {
    $monarch_cgi      = '/monarch';
    $monarch_css      = '/monarch/css';
    $monarch_html     = '/monarch/html';
    $monarch_images   = '/monarch/images';
    $monarch_js       = '/monarch/js';
    $monarch_download = '/monarch/download';
    $monarch_export   = '/monarch-export';
}
elsif ( -e '/usr/local/groundwork/config/db.properties' ) {
    $monarch_cgi      = '/monarch/cgi-bin';
    $monarch_css      = '/monarch';
    $monarch_html     = '/monarch';
    $monarch_images   = '/monarch/images';
    $monarch_js       = '/monarch';
    $monarch_download = '/monarch/download';
    $monarch_export   = '/monarch/download';
}
else {
    # Standalone Monarch (outside of GW Monitor) is no longer supported.
}

my $form_class      = 'row1';
my $global_cell_pad = 3;
my $indent_width    = '6';

my $disable_test_buttons = 0;  # set to 0 or 1

my $extend_page  = '<br><br><a href="#"></a><a href="#"></a><br><br><br><br><br><br><br><br><br><br><br><br><br><br>';

sub members(@) {
    my $title       = $_[1];
    my $name        = $_[2];
    my $members     = $_[3];
    my $nonmembers  = $_[4];
    my $req         = $_[5];
    my $size        = $_[6];
    my $doc         = $_[7];
    my $override    = $_[8];
    my $tab         = $_[9];
    my $indent      = $_[10];
    my $tmembers    = $_[11];
    my $tnonmembers = $_[12];
    return members_submit (undef, $title, $name, $members, $nonmembers, $req, $size, '', $doc, $override, $tab, $indent, $tmembers, $tnonmembers);
}

sub members_submit(@) {
    my $title       = $_[1];
    my $name        = $_[2];
    my $members     = $_[3];
    my $nonmembers  = $_[4];
    my $req         = $_[5];
    my $size        = $_[6];
    my $submit      = $_[7];
    my $doc         = $_[8];
    my $override    = $_[9];
    my $tab         = $_[10];
    my $indent      = $_[11];
    my $tmembers    = $_[12];
    my $tnonmembers = $_[13];
    my $tabindex   = $tab ? "tabindex=\"$tab\"" : '';

    $submit = $submit ? 'lowlight();selIt();submit();' : '';
    if ( !$size ) { $size = 15 }
    $req = $req ? "<td class=$form_class valign=baseline><font color=#CC0000>&nbsp;* required</font></td>" : '';

    my @members     = @{$members};
    my @nonmembers  = @{$nonmembers};
    my @tmembers    = defined($tmembers) ? @{$tmembers} : ();
    my @tnonmembers = defined($tnonmembers) ? @{$tnonmembers} : ();
    my $detail      = qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr class=no_border>);
    my $button_class     = 'submitbutton';
    my $row_class        = 'data0';
    my $label_class      = $form_class;
    my $item_display     = 'inline';
    my $alt_item_display = 'none';
    if ($override) {
	my $override_checked = $override eq 'checked' ? 'checked' : '';
	$detail .= qq(\n<td class=connect_top width='2%' valign=baseline style="padding-right: 0;"><input class=$form_class type=checkbox name=$name\_override $override_checked onclick="toggle_options('$name\_override','$name');toggle_enabled('$name\_override',[],'$name\_label',['$name\_remove_member','$name\_add_member']);toggle_options('$name\_override','$name\_nonmembers');"></td><td class=connect_top width="2%" valign=baseline style="padding-left: 0;">&nbsp;Inherit&nbsp;&nbsp;</td>);
	$row_class = 'data1';
	$label_class .= '_disabled' if $override_checked;
	$button_class     = $override_checked ? 'submitbutton_disabled' : 'submitbutton';
	$item_display     = $override_checked ? 'none'                  : 'inline';
	$alt_item_display = $override_checked ? 'inline'                : 'none';
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<td class=$row_class colspan=3>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>);
    if ($indent) {
	$detail .= "\n<td class=$form_class width='$indent_width' valign=top></td>";
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<td class=$label_class width="20%" height="100%" valign=baseline name="$name\_label" id="$name\_label">$title</td>);
    if ($doc) {
	$detail .=
	  "\n<td class=$form_class width='3%' valign=baseline align=center>\n<a class=orange href='#doc' title=\"$doc\" tabindex='-1'>&nbsp;?&nbsp;</a></td>";
    }
    else {
	$detail .= "\n<td class=$form_class width='3%' valign=baseline align=center>\n&nbsp;</td>";
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<td class=$form_class align=left rowspan=2>
<table cellspacing=0 cellpadding=0 align=left border=0>
<tr>
<td>
<select class=enabled name=$name id="$name.members" size=$size multiple style="display: $item_display;" $tabindex>);
    @members = sort { lc($a) cmp lc($b) } @members;
    foreach my $mem (@members) {
	$detail .= "\n<option value=\"$mem\">$mem</option>";
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
</select>
<select class=disabled name="_alt_$name" disabled size=$size multiple style="display: $alt_item_display;" $tabindex>);
    @tmembers = sort { lc($a) cmp lc($b) } @tmembers;
    foreach my $mem (@tmembers) {
	$detail .= "\n<option value=\"$mem\">$mem</option>";
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
</select>
</td>
<td class=$form_class align=left>
<table cellspacing=0 cellpadding=3 align=center border=0>
<tr>
<td class=$form_class align=center>
<input name=$name\_remove_member class=$button_class type=button value="Remove >>" onclick="delIt('$name');$submit" $tabindex>
</td>
</tr>
<tr>
<td class=$form_class align=center>
<input name=$name\_add_member class=$button_class type=button value="&nbsp;&nbsp;<< Add&nbsp;&nbsp;&nbsp;&nbsp;" onclick="addIt('$name');$submit" $tabindex>
</td>
</tr>
</table>
</td>
<td class=$form_class align=left>
<select class=enabled name="$name\_nonmembers" id="$name.nonmembers" size=$size multiple style="display: $item_display;" $tabindex>);
    @nonmembers = sort { lc($a) cmp lc($b) } @nonmembers;
    MEM: foreach my $nmem (@nonmembers) {
	foreach my $mem (@members) {
	    next MEM if $nmem eq $mem;
	}
	$detail .= "\n<option value=\"$nmem\">$nmem</option>";
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
</select>
<select class=disabled name="_alt_$name\_nonmembers" disabled size=$size multiple style="display: $alt_item_display;" $tabindex>);
    @tnonmembers = sort { lc($a) cmp lc($b) } @tnonmembers;
    TMEM: foreach my $nmem (@tnonmembers) {
	foreach my $mem (@tmembers) {
	    next TMEM if $nmem eq $mem;
	}
	$detail .= "\n<option value=\"$nmem\">$nmem</option>";
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
</select>
</td>
$req
</tr>
</table>
</td>
</tr>
<!-- This next empty row is here to address a background-color problem in Chrome. -->
<tr>
<td class=$form_class></td>
<td class=$form_class></td>
</tr>
</table>
</td>
</tr>);
    return $detail;
}

sub hidden(@) {
    my $hidden = $_[1];
    my %hidden = %{$hidden};
    my $detail = "\n<tr style='display:none'>\n<td>";
    foreach my $key ( sort keys %hidden ) {
	if ( $hidden{$key} ) {
	    $detail .= "\n<input type=hidden name=\"$key\" value=\"$hidden{$key}\">";
	}
    }
    $detail .= "\n</td>\n</tr>";
    return $detail;
}

sub checkbox(@) {
    my $title    = $_[1];
    my $name     = $_[2];
    my $value    = $_[3];
    my $doc      = $_[4];
    my $override = $_[5];
    my $tab      = $_[6];
    my $indent   = $_[7];
    my $tvalue   = $_[8];
    my $control  = $_[9];
    my $tag      = $_[10];
    my $tabindex = $tab ? "tabindex=\"$tab\"" : '';
    my $detail   = qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr class=no_border>);
    my $row_class     = 'data0';
    my $label_class   = $form_class;
    my $item_class    = 'enabled';
    my $item_disabled = '';
    if ($override) {
	my $override_checked = $override eq 'checked' ? 'checked' : '';
	$detail .= qq(\n<td class=connect_top width="2%" valign=baseline style="padding-right: 0;"><input class=$form_class type=checkbox name=$name\_override $override_checked onclick="toggle_enabled('$name\_override','$name','$name\_label');"></td><td class=connect_top width="2%" valign=baseline style="padding-left: 0;">&nbsp;Inherit&nbsp;&nbsp;</td>);
	$row_class = 'data1';
	$label_class .= '_disabled' if $override_checked;
	$item_class    = $override_checked ? 'disabled' : 'enabled';
	$item_disabled = $override_checked ? 'disabled' : '';
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<td class=$row_class>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>);
    if ($indent) {
	$detail .= "\n<td class=$form_class width='$indent_width' valign=top></td>";
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<td class=$label_class width="20%" name="$name\_label" id="$name\_label">$title</td>);
    if ($doc) {
	$detail .= "\n<td class=$form_class width='3%' align=center>\n<a class=orange href='#doc' title=\"$doc\" tabindex='-1'>&nbsp;?&nbsp;</a></td>";
    }
    else {
	$detail .= "\n<td class=$form_class width='3%' align=center>\n&nbsp;</td>";
    }
    # Handle non-automatic coercions.
    $value = 0 if !defined($value) || $value eq '' || $value eq '-zero-';
    my $value_checked = $value == 1 ? 'checked' : '';
    my $alt = defined($tvalue) ? ( $tvalue eq '1' ? 'alt="true"' : 'alt="false"' ) : "alt='\0'";
    my $onclick = $control ? qq(onclick="toggle_enabled('$name','$control','$control\_label');") : '';
    my $td_width = $tag ? 'width="2%"' : '';
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<td class=$form_class align=left $td_width style="padding-right: 0;"><input class=$item_class type=checkbox name=$name value=1 $value_checked $alt $item_disabled $onclick $tabindex></td>);
    if ($tag) {
	$detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<td class=$form_class align=left style="padding-left: 0;">&nbsp;$tag&nbsp;</td>);
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
</tr>
</table>
</td>
</tr>);
    return $detail;
}

sub checkbox_override(@) {
    my $title    = $_[1];
    my $name     = $_[2];
    my $value    = $_[3];
    my $doc      = $_[4];
    my $tab      = $_[5];
    my $tag      = $_[6] || 'Inherit';
    my $onclick  = $_[7];
    my $tabindex = $tab ? "tabindex=\"$tab\"" : '';
    my $detail   = qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr class=no_border>
<td class=data0>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>);

    my $value_checked = $value ? 'checked' : '';
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<td class=$form_class width="20%" align=left>$title</td>);
    if ($doc) {
	$detail .= "\n<td class=$form_class width='3%' align=center>\n<a class=orange href='#doc' title=\"$doc\" tabindex='-1'>&nbsp;?&nbsp;</a></td>";
    }
    else {
	$detail .= "\n<td class=$form_class width='3%' align=left>\n&nbsp;</td>";
    }
    $onclick = defined($onclick) ? "$onclick;" : '';
    $onclick .= 'lowlight();submit()';
    $detail .= qq(
<td class=$form_class align=left width="2%" style="padding-right: 0;"><input class=$form_class type=checkbox name=$name $value_checked onclick="$onclick" $tabindex></td>
<td class=$form_class align=left style="padding-left: 0;">&nbsp;$tag&nbsp;</td>
</tr>
</table>
</td>
</tr>);
    return $detail;
}

sub checkbox_left(@) {
    my $title    = $_[1];
    my $name     = $_[2];
    my $value    = $_[3];
    my $override = $_[4];
    my $tab      = $_[5];
    my $tabindex = $tab ? "tabindex=\"$tab\"" : '';
    my $detail   = qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=data0>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>
<td class=$form_class width="20%" align=right>);

    my $value_checked = $value == 1 ? 'checked' : '';
    $detail .= "\n<input class=$form_class type=checkbox name=$name value=1 $value_checked $tabindex>";
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
</td>
<td class=$form_class>$title</td>
</tr>
</table>
</td>
</tr>);
    return $detail;
}

sub checkbox_list(@) {
    my $title    = $_[1];
    my $name     = $_[2];
    my $list     = $_[3];
    my @list     = @{$list};
    my $selected = $_[4];
    my $req      = $_[5];
    my $doc      = $_[6];
    my $override = $_[7];
    my $tab      = $_[8];
    my $tabindex = $tab ? "tabindex=\"$tab\"" : '';
    $req = $req ? '<font color=#CC0000>&nbsp;* required</font>' : '';
    my @selected = @{$selected};
    my $detail   = qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>);
    if ($override) {
	my $override_checked = $override eq 'checked' ? 'checked' : '';
	$detail .= "\n<td class=$form_class width='2%' valign=top><input class=$form_class type=checkbox name=$name\_override $override_checked $tabindex></td>";
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<td class=data0>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>);

    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<td class=$form_class width="20%" valign=top>$title $req</td>);
    if ($doc) {
	$detail .=
	  "\n<td class=$form_class width='3%' valign=top align=center>\n<a class=orange href='#doc' title=\"$doc\" tabindex='-1'>&nbsp;?&nbsp;</a></td>";
    }
    else {
	$detail .= "\n<td class=$form_class width='3%' align=center>\n&nbsp;</td>";
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<td class=$form_class>);
    my $got_selected = undef;
    foreach my $item (@list) {
	my $title = $item;
	$title =~ s/_/ /g;
	foreach my $selected (@selected) {
	    if ( $item eq $selected ) { $got_selected = 1 }
	}
	if ($got_selected) {
	    $got_selected = undef;
	    $detail .= "\n<input class=$form_class type=checkbox name=$name value=\"$item\" checked $tabindex>&nbsp;\u$title<br>";
	}
	else {
	    $detail .= "\n<input class=$form_class type=checkbox name=$name value=\"$item\" $tabindex>&nbsp;\u$title<br>";
	}
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
</td>
</tr>
</table>
</td>
</tr>);
    return $detail;
}

sub hash_hash_display(@) {
    my $title    = $_[1];
    my $hash     = $_[2];
    my $max_size = $_[3];
    my $doc      = $_[4];
    my %hash     = %{$hash};
    my $display  = $title;
    $display =~ s/://g;
    $display =~ s/s$//g;
    if ( $display =~ /^use$/i ) { $display = "template" }
    my $size = 0;
    foreach my $item (keys %hash) {
	$size += scalar keys %{ $hash{$item} };
    }
    $size = $max_size if $size > $max_size;
    $size = 1 if $size < 1;
    ## Apparently, we need to take the <html> line-height into account, rounding up.
    $size = int(($size + 1) * 1.2);
    my @rows = ();
    if ( not %hash ) {
	push @rows, "\n<tr><td>-- no \L$display" . "s --</td></tr>";
    }
    else {
	foreach my $item1 (sort { lc($a) cmp lc($b) } keys %hash) {
	    foreach my $item2 (sort { lc($a) cmp lc($b) } keys %{ $hash{$item1} }) {
		push @rows, "\n<tr><td class=padded>$item1</td><td class=padded>$item2</td></tr>";
	    }
	}
    }
    my $detail = qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=data0>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tbody>
<tr>
<td class=$form_class valign=top width="20%">$title</td>);
    if ($doc) {
	$detail .=
	  "\n<td class=$form_class valign=top align=center width='3%'><a class=orange href='#doc' title=\"$doc\" tabindex='-1'>&nbsp;?&nbsp;</a></td>";
    }
    else {
	$detail .= "\n<td class=$form_class align=center width='3%'>&nbsp;</td>";
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<td class=$form_class>
<span style="display: inline-block; border: 1px solid #000000; max-height: ${size}em; overflow-x: visible; overflow-y: scroll">
<table cellpadding=0 cellspacing=0 align=left border=0 bgcolor="#FFFFFF">
<tbody>
@rows
</tbody>
</table>
</span>
</td>
</tr>
</tbody>
</table>
</td>
</tr>);
    return $detail;
}

# write-only list display; no user selection
sub list_box_display(@) {
    my $title    = $_[1];
    my $name     = $_[2];
    my $list     = $_[3];
    my @list     = @{$list};
    my $max_size = $_[4];
    my $doc      = $_[5];
    my $display  = $title;
    $display =~ s/://g;
    $display =~ s/s$//g;
    if ( $display =~ /^use$/i ) { $display = "template" }
    my $size = (@list > $max_size) ? $max_size : (scalar @list);
    $size = 1 if $size < 1;
    my @options = ();
    if ( not defined $list[0] ) {
	push @options, "\n<option value=''>-- no \L$display" . "s --</option>";
    }
    else {
	@list = sort { lc($a) cmp lc($b) } @list;
	foreach my $item (@list) {
	    push @options, "\n<option value=\"$item\">$item</option>";
	}
    }
    my $detail = qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=data0>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>
<td class=$form_class valign=baseline width="20%">$title</td>);
    if ($doc) {
	$detail .=
	  "\n<td class=$form_class width='3%' valign=baseline align=center><a class=orange href='#doc' title=\"$doc\" tabindex='-1'>&nbsp;?&nbsp;</a></td>";
    }
    else {
	$detail .= "\n<td class=$form_class width='3%' align=center>&nbsp;</td>";
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<td class=$form_class>
<select name=$name size=$size disabled>
@options
</select>
</td>
</tr>
</table>
</td>
</tr>);
    return $detail;
}

sub list_box_multiple(@) {
    my $title    = $_[1];
    my $name     = $_[2];
    my $list     = $_[3];
    my $selected = $_[4];
    my $req      = $_[5];
    my $doc      = $_[6];
    my $override = $_[7];
    my $tab      = $_[8];
    my $indent   = $_[9];
    my $tvalue   = $_[10];
    my $tabindex = $tab ? "tabindex=\"$tab\"" : '';
    $req = $req ? "<td class=$form_class valign=top><font color=#CC0000>&nbsp;* required</font></td>" : '';
    my @list     = @{$list};
    my @selected = @{$selected};
    my @tvalue   = defined($tvalue) ? @{$tvalue} : ();
    my $display  = $title;
    $display =~ s/://g;
    if ( $display =~ /^use$/i ) { $display = "template" }
    my $detail = qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>);
    my $row_class     = 'data0';
    my $label_class      = $form_class;
    my $item_display     = 'inline';
    my $alt_item_display = 'none';
    if ($override) {
	my $override_checked = $override eq 'checked' ? 'checked' : '';
	$detail .= qq(\n<td class=connect_top width="2%" valign=baseline style="padding-right: 0;"><input class=$form_class type=checkbox name=$name\_override $override_checked onclick="toggle_options('$name\_override','$name','$name\_label');"></td><td class=connect_top width="2%" valign=baseline style="padding-left: 0;">&nbsp;Inherit&nbsp;&nbsp;</td>);
	$row_class = 'data1';
	$label_class .= '_disabled' if $override_checked;
	$item_display     = $override_checked ? 'none'   : 'inline';
	$alt_item_display = $override_checked ? 'inline' : 'none';
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<td class=$row_class colspan=3>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>);
    if ($indent) {
	$detail .= "\n<td class=$form_class width='$indent_width' valign=top></td>";
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<td class=$label_class width="20%" valign=top name="$name\_label" id="$name\_label">$title</td>);
    if ($doc) {
	$detail .=
	  "\n<td class=$form_class width='3%' valign=top align=center><a class=orange href='#doc' title=\"$doc\" tabindex='-1'>&nbsp;?&nbsp;</a></td>";
    }
    else {
	$detail .= "\n<td class=$form_class width='3%' valign=top align=center>&nbsp;</td>";
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<td class=$form_class>
<table cellspacing=0 align=left border=0>
<tr>
<td class=$form_class>
<select class=enabled name=$name size=7 multiple style="display: $item_display;" $tabindex>);
    my $no_list = !$list[0];
    if ($no_list) {
	$detail .= "\n<option selected value=''></option>";
	$detail .= "\n<option value=''>-- no \L$display" . "s --</option>";
    }
    else {
	my $opt_selected = $selected[0] ? '' : 'selected';
	$detail .= "\n<option $opt_selected value=''></option>";
	@list = sort { lc($a) cmp lc($b) } @list;
	foreach my $item (@list) {
	    $opt_selected = '';
	    foreach my $sel (@selected) {
		if ( defined($sel) && $item eq $sel ) {
		    $opt_selected = 'selected';
		    last;
		}
	    }
	    $detail .= "\n<option $opt_selected value=\"$item\">$item</option>";
	}
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
</select>
<select class=disabled name="_alt_$name" disabled size=7 multiple style="display: $alt_item_display;" $tabindex>);
    if ($no_list) {
	$detail .= "\n<option selected value=''></option>";
	$detail .= "\n<option value=''>-- no \L$display" . "s --</option>";
    }
    else {
	my $opt_selected = $tvalue[0] ? '' : 'selected';
	$detail .= "\n<option $opt_selected value=''></option>";
	foreach my $item (@list) {
	    $opt_selected = '';
	    foreach my $ival (@tvalue) {
		if ( defined($ival) && $item eq $ival ) {
		    $opt_selected = 'selected';
		    last;
		}
	    }
	    $detail .= "\n<option $opt_selected value=\"$item\">$item</option>";
	}
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
</select>
</td>
$req
</tr>
</table>
</td>
</tr>
</table>
</td>
</tr>);
    return $detail;
}

sub list_box(@) {
    my $title    = $_[1];
    my $name     = $_[2];
    my $list     = $_[3];
    my $selected = $_[4];
    my $req      = $_[5];
    my $doc      = $_[6];
    my $override = $_[7];
    my $tab      = $_[8];
    my $indent   = $_[9];
    my $tvalue   = $_[10];
    my $tabindex = $tab ? "tabindex=\"$tab\"" : '';
    $req = $req ? '<font color=#CC0000>&nbsp;* required</font>' : '';
    my @list    = @{$list};
    my $display = $title;
    $display =~ s/://g;
    if ( $display =~ /^use$/i ) { $display = "template" }
    my $detail = qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr class=no_border>);
    my $row_class        = 'data0';
    my $label_class      = $form_class;
    my $item_display     = 'inline';
    my $alt_item_display = 'none';
    if ($override) {
	my $override_checked = $override eq 'checked' ? 'checked' : '';
	$detail .= qq(\n<td class=connect_top width="2%" valign=baseline style="padding-right: 0;"><input class=$form_class type=checkbox name=$name\_override $override_checked onclick="toggle_options('$name\_override','$name','$name\_label');"></td><td class=connect_top width="2%" valign=baseline style="padding-left: 0;">&nbsp;Inherit&nbsp;&nbsp;</td>);
	$row_class = 'data1';
	$label_class .= '_disabled' if $override_checked;
	$item_display     = $override_checked ? 'none'   : 'inline';
	$alt_item_display = $override_checked ? 'inline' : 'none';
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<td class=$row_class colspan=3>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>);
    if ($indent) {
	$detail .= "\n<td class=$form_class width='$indent_width' valign=top></td>";
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<td class=$label_class width="20%" name="$name\_label" id="$name\_label">$title</td>);
    if ($doc) {
	$detail .=
	  "\n<td class=$form_class width='3%' align=center>\n<a class=orange href='#doc' title=\"$doc\" tabindex='-1'>&nbsp;?&nbsp;</a>\n</td>";
    }
    else {
	$detail .= "\n<td class=$form_class width='3%' align=center>\n&nbsp;</td>";
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<td class=$form_class align=left>
<select class=enabled name="$name" style="display: $item_display;" $tabindex>);
    my $no_list = !$list[0];
    if ($no_list) {
	$detail .= "\n<option selected value=''></option>";
	$detail .= "\n<option value=''>-- no \L$display" . "s --</option>";
    }
    else {
	my $opt_selected = $selected ? '' : 'selected';
	$detail .= "\n<option $opt_selected value=''></option>";
	@list = sort { lc($a) cmp lc($b) } @list;
	foreach my $item (@list) {
	    $opt_selected = ( defined($selected) && $item eq $selected ) ? 'selected' : '';
	    $detail .= "\n<option $opt_selected value=\"$item\">$item</option>";
	}
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
</select>
<select class=disabled name="_alt_$name" disabled style="display: $alt_item_display;" $tabindex>);
    if ($no_list) {
	$detail .= "\n<option selected value=''></option>";
	$detail .= "\n<option value=''>-- no \L$display" . "s --</option>";
    }
    else {
	my $opt_selected = $tvalue ? '' : 'selected';
	$detail .= "\n<option selected value=''></option>";
	foreach my $item (@list) {
	    $opt_selected = ( defined($tvalue) && $item eq $tvalue ) ? 'selected' : '';
	    $detail .= "\n<option $opt_selected value=\"$item\">$item</option>";
	}
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
</select>
$req
</td>
</tr>
</table>
</td>
</tr>);
    return $detail;
}

sub list_box_submit(@) {
    my $title    = $_[1];
    my $name     = $_[2];
    my $list     = $_[3];
    my $selected = $_[4];
    my $req      = $_[5];
    my $doc      = $_[6];
    my $tab      = $_[7];
    my $disabled = $_[8] ? 'disabled' : '';
    my $onchange = $_[9];
    my $tabindex = $tab ? "tabindex=\"$tab\"" : '';
    $req = $req ? '<font color=#CC0000>&nbsp;* required</font>' : '';
    my $select_class = $disabled ? 'disabled' : 'enabled';
    my @list         = @{$list};
    my $display      = $title;
    $display =~ s/://g;
    if ( $display =~ /^use$/i ) { $display = "template" }
    my $label_class   = $form_class;
    $label_class .= '_disabled' if $disabled;
    my $detail = qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr class=no_border>
<td class=data0 colspan=3>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>
<td class=$label_class width="20%">$title</td>);

    if ($doc) {
	$detail .=
	  "\n<td class=$form_class width='3%' valign=top align=center>\n<a class=orange href='#doc' title=\"$doc\" tabindex='-1'>&nbsp;?&nbsp;</a></td>";
    }
    else {
	$detail .= "\n<td class=$form_class width='3%' align=center>\n&nbsp;</td>";
    }
    $onchange = defined($onchange) ? "$onchange;" : '';
    $onchange .= 'lowlight();submit()';
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<td class=$form_class align=left>
<select name=$name onchange="$onchange" class='$select_class' $tabindex>);
    if ( !$list[0] ) {
	$detail .= "\n<option selected value=''></option>";
	$detail .= "\n<option disabled value=''>-- no \L$display" . "s --</option>";
    }
    else {
	if ($selected) {
	    $detail .= "\n<option value=''>-- leave as-is --</option>";
	}
	else {
	    $detail .= "\n<option selected value=''></option>";
	}
	@list = sort { lc($a) cmp lc($b) } @list;
	foreach my $item (@list) {
	    if ( defined($selected) && $item eq $selected ) {
		$detail .= "\n<option selected value=\"$item\">$item</option>";
	    }
	    else {
		$detail .= "\n<option $disabled value=\"$item\">$item</option>";
	    }
	}
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
</select>
$req
</td>
</tr>
</table>
</td>
</tr>);
    return $detail;
}

sub command_test() {
    my $results      = $_[1];
    my $host         = $_[2];
    my $args         = $_[3];
    my $service_desc = $_[4];
    my $tab          = $_[5];
    my $tabindex     = $tab ? "tabindex=\"$tab\"" : '';
    my $button_class = $disable_test_buttons ? 'submitbutton_disabled' : 'submitbutton';
    my $test_enabled = $disable_test_buttons ? 'disabled' : '';

    unless ($results) { $results = "$args<br>" }
    $service_desc = '' if not defined $service_desc;
    my $host_doc = 'Specify the name of an existing host within Monarch.  This will be used to substitute corresponding values for $HOSTNAME$, $HOSTALIAS$, and $HOSTADDRESS$ macro references in the command, when you press the Test button.';
    my $args_doc = 'Specify command-argument values, separated by ! characters (exclamation points).  These will be used to substitute corresponding values for $ARG1$, $ARG2$, and similar macro references in the command, when you press the Test button.';
    my $serv_doc = 'Specify the name of a host service within Monarch.  This will be used to substitute a value for $SERVICEDESC$ macro references in the command, when you press the Test button.';
    $args = defined($args) ? HTML::Entities::encode($args) : '';
    my $rows = int( length($args) / 60 ) + 2;
    my $onclick = 'lowlight();submit()';
    my $detail = qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=data0>
<table width="100%" cellpadding=5 cellspacing=0 align=left border=0 style="table-layout: fixed;">
<tr>
<td class=$form_class valign=top width="7%">Test:</td>
<td class=$form_class width="92%">

<table width=auto cellpadding=5 cellspacing=0 align=left border=0>
<tr>
<td class=$form_class align=right>Host:&nbsp;</td>
<td class=$form_class width='3%' align=center>\n<a class=orange href='#host_doc' title=\"$host_doc\" tabindex='-1'>&nbsp;?&nbsp;</a>\n</td>
<td class=$form_class><input type=text size=50 name=host value="$host" $tabindex></td>
</tr>
<tr>
<td class=$form_class valign=baseline style="padding-top: 9px;" align=right>Arguments:&nbsp;</td>
<td class=$form_class valign=baseline style="padding-top: 9px;" width='3%' align=center>\n<a class=orange href='#args_doc' title=\"$args_doc\" tabindex='-1'>&nbsp;?&nbsp;</a>\n</td>
<td class=$form_class><textarea rows=$rows cols=60 name=arg_string wrap=soft $tabindex>$args</textarea></td>
</tr>
<tr>
<td class=$form_class align=right>Service&nbsp;description:&nbsp;</td>
<td class=$form_class width='3%' align=center>\n<a class=orange href='#serv_doc' title=\"$serv_doc\" tabindex='-1'>&nbsp;?&nbsp;</a>\n</td>
<td class=$form_class><input type=text size=60 name=service_desc value="$service_desc" $tabindex></td>
</tr>
</table>

</td>
<td class=$form_class width="1%" align=center>&nbsp;</td>
</tr>
<tr>
<td class=$form_class width="7%" align=center><input class=$button_class type=submit name=test_command value="Test" $test_enabled onclick="$onclick" $tabindex></td>
<td class=output valign=top width="92%" align=left>$results</td>
<td class=$form_class width="1%">&nbsp;</td>
</tr>
<tr>
<td class=$form_class colspan=3 style="height: 0.5em;"></td>
</tr>
</table>
</td>
</tr>);
    return $detail;
}

sub test_service_check() {
    my $results  = $_[1];
    my $host     = $_[2];
    my $args     = $_[3];
    my $tab      = $_[4];
    my $onclick  = $_[5];
    my $tabindex = $tab ? "tabindex=\"$tab\"" : '';
    my $button_class = $disable_test_buttons ? 'submitbutton_disabled' : 'submitbutton';
    my $test_enabled = $disable_test_buttons ? 'disabled' : '';

    unless ($results) {
	$results = defined($args) ? "$args<br>" : '<br>';
    }
    $host = '' if not defined $host;

    $onclick = defined($onclick) ? "$onclick;" : '';
    $onclick .= 'lowlight();submit()';
    my $detail = qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=data0>
<table width="100%" cellpadding=5 cellspacing=0 align=left border=0 style="table-layout: fixed;">
<tr>
<td class=$form_class width="7%">Test:</td>
<td class=$form_class width="92%">Host:&nbsp;&nbsp;<input type=text size=50 name=host value="$host" $tabindex></td>
<td class=$form_class width="1%" align=center>&nbsp;</td>
</tr>
<tr>
<td class=$form_class width="7%" align=center><input class=$button_class type=submit name=test_command value="Test" $test_enabled onclick="$onclick" $tabindex></td>
<td class=output width="92%" align=left>$results</td>
<td class=$form_class width="1%">&nbsp;</td>
</tr>
<tr>
<td class=$form_class colspan=3 style="height: 0.5em;"></td>
</tr>
</table>
</td>
</tr>);
    return $detail;
}

sub command_select() {
    my $list     = $_[1];
    my $selected = $_[2];
    my $tab      = $_[3];
    my $tabindex = $tab ? "tabindex=\"$tab\"" : '';
    my @list     = @{$list};
    my %selected = %{$selected};

    my $detail = qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=data0>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>);
    my $temp = qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=$form_class width="5%">
<input type=radio class=radio name=task value=new_plugin $selected{'d'}>
</td>
<td class=$form_class>
Install plugin
</td>
<td class=$form_class>
&nbsp;
</td>
</tr>);
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=$form_class width="5%">
<input type=radio class=radio name=task value=resource $selected{'d'}>
</td>
<td class=$form_class>
New command from an existing plugin
</td>
<td class=$form_class>
&nbsp;
</td>
</tr>
<tr>
<td class=$form_class width="5%">
<input type=radio class=radio name=task value=copy $selected{'d'}>
</td>
<td class=$form_class>
Clone a command:
</td>
<td class=$form_class align=left>
<select name=source>);
    if ( !$list[0] ) {
	$detail .= "\n<option selected value=''></option>";
	$detail .= "\n<option value=''>-- no check commands --</option>";
    }
    else {
	if ($selected) {
	    $detail .= "\n<option value=''></option>";
	}
	else {
	    $detail .= "\n<option selected value=''></option>";
	}
	@list = sort { lc($a) cmp lc($b) } @list;
	foreach my $item (@list) {
	    if ( $item eq $selected ) {
		$detail .= "\n<option selected value=\"$item\">$item</option>";
	    }
	    else {
		$detail .= "\n<option value=\"$item\">$item</option>";
	    }
	}
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
</select>
</td>
</tr>

);

    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
</tr>
</table>
</td>
</tr>);
    return $detail;
}

sub new_backup(@) {
    my $title    = $_[1];
    my $ann_doc  = $_[2];
    my $fro_doc  = $_[3];
    my $button   = $_[4];
    my $tab      = $_[5];
    my $tabindex = $tab ? "tabindex=\"$tab\"" : '';

    my $detail = qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=data0>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>
<td class=wizard_title_heading style="padding: 7px;" align=left colspan=5>$title</td>
</tr>
<tr>
<td>
<table cellpadding=0 cellspacing=0 align=left border=0>
<tr>
<td>
<table cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>
<td class=$form_class align=left colspan=2 width="13%">Annotation:</td>);
    if ($ann_doc) {
	$detail .= "\n<td class=$form_class width='3%' align=center>\n<a class=orange href='#doc' title=\"$ann_doc\" tabindex='-1'>&nbsp;?&nbsp;</a></td>";
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<td class=$form_class align=left width="70%">
<textarea rows=4 cols=60 name=annotation wrap=soft $tabindex></textarea>
</td>
</tr>
<tr>
<td class=$form_class align=left colspan=2 width="13%">Lock:</td>);
    if ($fro_doc) {
	$detail .= "\n<td class=$form_class width='3%' align=center>\n<a class=orange href='#doc' title=\"$fro_doc\" tabindex='-1'>&nbsp;?&nbsp;</a></td>";
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<td class=$form_class align=left width="70%"><input class=$form_class type=checkbox name=lock value='lock' $tabindex></td>
</tr>
</table>
</td>
<td class=$form_class align=left>&nbsp;&nbsp;</td>);
    if ($button) {
	$detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<td class=$form_class align=left><input class=submitbutton type=submit name=back_up value="Back up" $tabindex></td>);
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
</tr>
</table>
</td>
</tr>
</table>
</td>
</tr>);

    return $detail;
}

sub backup_select() {
    my $title    = $_[1];
    my $choose   = $_[2];
    my $backups  = $_[3];
    my $locked   = $_[4];
    my $doc      = $_[5];
    my $tab      = $_[6];
    my $tabindex = $tab ? "tabindex=\"$tab\"" : '';

    my $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=data0>
<table width="100%" cellpadding=7 cellspacing=0 align=left border=0>
<tr>
<td class=wizard_title_heading align=left colspan=5>$title</td>
</tr>
<tr>
<td class=row1 colspan=4>$doc</td>
</tr>
<tr>
<td>
<table width="100%" cellpadding=3 cellspacing=0 align=left border=0>
<tr>
);
    if ($choose) {
	$detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<td class=column_head align=left></td>);
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<td class=column_head align=left>Backup&nbsp;Date/Time</td>
<td class=column_head align=left>Locked?&nbsp;&nbsp;</td>
<td class=column_head align=left colspan=2>Annotation</td>
</tr>);
    my $class = 'row_dk';
    foreach my $backup_time ( sort keys %$backups ) {
	( my $human_time = $backup_time ) =~ s/_(\d\d)-(\d\d)-/&nbsp;$1:$2:/;
	my $annotation = $backups->{$backup_time};
	my $locked_tag = $locked->{$backup_time} ? 'locked' : '';
	$class = $class eq 'row_lt' ? 'row_dk' : 'row_lt';
	$detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>);
	if ($choose) {
	    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<td class=$class align=left width="2%" valign=baseline><input class=$form_class type=checkbox name=backup_time value='$backup_time' $tabindex></td>);
	}
	$detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<td class=$class align=left width="7%" valign=baseline>$human_time&nbsp;&nbsp;</td>
<td class=$class align=center width="7%" valign=baseline>$locked_tag&nbsp;&nbsp;&thinsp;</td>
<td class=$class align=left valign=baseline>$annotation</td>
</tr>);
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
</table>
</td>
</tr>
</table>
</td>
</tr>);
    return $detail;
}

sub display_hidden(@) {
    my $title  = $_[1];
    my $name   = $_[2];
    my $value  = $_[3];
    my $doc    = $_[4];
    my $parent = $_[5];
    if ($parent) { $form_class = 'parent' }
    my $display = defined($value) ? $value : '';
    my $detail  = qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr class=no_border>
<td class=data0 colspan=3>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>
<td class=$form_class width="20%" valign=top>$title);
    if ($name) {
	$detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<input type=hidden name=$name value="$value">);
    }
    $detail .= "</td>";
    if ($doc) {
	$detail .=
	  "\n<td class=$form_class width='3%' valign=top align=center>\n<a class=orange href='#doc' title=\"$doc\" tabindex='-1'>&nbsp;?&nbsp;</a></td>";
    }
    else {
	$detail .= "\n<td class=$form_class width='3%' align=center>\n&nbsp;</td>";
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<td class=$form_class>$display
</td>
</tr>
</table>
</td>
</tr>);
    return $detail;
}

sub text_box(@) {
    my $title    = $_[1];
    my $name     = $_[2];
    my $value    = $_[3];
    my $size     = $_[4];
    my $req      = $_[5];
    my $doc      = $_[6];
    my $override = $_[7];
    my $tab      = $_[8];
    my $indent   = $_[9];
    my $tvalue   = $_[10];
    my $tabindex = $tab ? "tabindex=\"$tab\"" : '';

    if ( !$size ) { $size = 50 }
    $req = $req ? '<font color=#CC0000>&nbsp;* required</font>' : '';
    $value = defined($value) ? HTML::Entities::encode($value) : '';
    my $alt = defined($tvalue) ? ( 'alt="' . HTML::Entities::encode($tvalue) . '"' ) : "alt='\0'";
    my $detail = qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr class=no_border>);
    my $row_class     = 'data0';
    my $label_class   = $form_class;
    my $item_class    = 'enabled';
    my $item_disabled = '';
    if ($override) {
	my $override_checked = $override eq 'checked' ? 'checked' : '';
	$detail .= qq(\n<td class=connect_top width="2%" valign=baseline style="padding-right: 0;"><input class=$form_class type=checkbox name=$name\_override $override_checked onclick="toggle_enabled('$name\_override','$name','$name\_label');"></td><td class=connect_top width="2%" valign=baseline style="padding-left: 0;">&nbsp;Inherit&nbsp;&nbsp;</td>);
	$row_class = 'data1';
	$label_class .= '_disabled' if $override_checked;
	$item_class    = $override_checked ? 'disabled' : 'enabled';
	$item_disabled = $override_checked ? 'disabled' : '';
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<td class=$row_class colspan=3>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>);
    if ($indent) {
	$detail .= "\n<td class=$form_class width='$indent_width' valign=top></td>";
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<td class=$label_class width="20%" name="$name\_label" id="$name\_label" >$title</td>);
    if ($doc) {
	$detail .= "\n<td class=$form_class width='3%' align=center>\n<a class=orange href='#doc' title=\"$doc\" tabindex='-1'>&nbsp;?&nbsp;</a></td>";
    }
    else {
	$detail .= "\n<td class=$form_class width='3%' align=center>\n&nbsp;</td>";
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<td class=$form_class>
<input class=$item_class type=text size=$size name=$name value="$value" $alt $item_disabled $tabindex>
$req
</td>
</tr>
</table>
</td>
</tr>);
    return $detail;
}

sub password_box(@) {
    my $title = $_[1];
    my $name  = $_[2];
    my $size  = $_[3];
    my $req   = $_[4];
    if ( !$size ) { $size = 50 }
    $req = $req ? '<font color=#CC0000>&nbsp;* required</font>' : '';
    my $detail = qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=data>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>
<td class=$form_class width="20%">$title</td>
<td class=$form_class width="3%" align=center>&nbsp;</td>
<td class=$form_class>
<input type=password size=$size name=$name value=''>
$req
</td>
</tr>
</table>
</td>
</tr>);
    return $detail;
}

sub text_area(@) {
    my $title    = $_[1];
    my $name     = $_[2];
    my $value    = $_[3];
    my $rows     = $_[4];
    my $size     = $_[5];
    my $req      = $_[6];
    my $doc      = $_[7];
    my $override = $_[8];
    my $tab      = $_[9];
    my $indent   = $_[10];
    my $tvalue   = $_[11];
    my $disabled = $_[12];
    my $tabindex = $tab ? "tabindex=\"$tab\"" : '';
    if ( !$rows ) { $rows = 3 }
    if ( !$size ) { $size = 40 }
    my $title_width  = '20%';
    my $text_width   = '';
    $value = '' if not defined $value;
    my $data_alt = defined($tvalue) ? ( 'data-alt="' . HTML::Entities::encode($tvalue) . '"' ) : "data-alt='\0'";

    if ($size eq '100%') {
	$size         = 40;
	$title_width  = '2%';
	$text_width   = 'style="width: 99%;"';
    }
    $req = $req ? '<font color=#CC0000>&nbsp;* required</font>' : '';
    my $detail = qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr class=no_border>);
    my $row_class        = 'data0';
    my $label_class      = $form_class;
    my $item_class       = 'enabled';
    my $item_disabled    = '';
    my $override_checked = $disabled ? 'checked' : '';
    if ($override) {
	$override_checked = $override eq 'checked' ? 'checked' : '';
	$detail .= qq(\n<td class=connect_top width='2%' valign=baseline style="padding-right: 0;"><input class=$form_class type=checkbox name=$name\_override $override_checked onclick="toggle_enabled('$name\_override','$name','$name\_label');"></td><td class=connect_top width="2%" valign=baseline style="padding-left: 0;">&nbsp;Inherit&nbsp;&nbsp;</td>);
    }
    if ( $disabled || $override ) {
	$row_class = 'data1';
	$label_class .= '_disabled' if $override_checked;
	$item_class    = $override_checked ? 'disabled' : 'enabled';
	$item_disabled = $override_checked ? 'disabled' : '';
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<td class=$row_class colspan=3>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>);
    if ($indent) {
	$detail .= "\n<td class=$form_class width='$indent_width' valign=top></td>";
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<td class=$label_class valign=top width="$title_width" name="$name\_label" id="$name\_label">$title</td>);
    if ($doc) {
	$detail .=
	  "\n<td class=$form_class width='3%' valign=top align=center>\n<a class=orange href='#doc' title=\"$doc\" tabindex='-1'>&nbsp;?&nbsp;</a></td>";
    }
    elsif (! $text_width) {
	$detail .= "\n<td class=$form_class width='3%' align=center>\n&nbsp;</td>";
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<td class=$form_class>
<textarea class=$item_class name=$name rows=$rows cols=$size $text_width wrap=soft $data_alt $item_disabled $tabindex>$value</textarea>
$req
</td>
</tr>
</table>
</td>
</tr>);
    return $detail;
}

sub stalking_options(@) {
    my $obj      = $_[1];
    my $selected = $_[2];
    my $req      = $_[3];
    my $doc      = $_[4];
    my $override = $_[5];
    my $tab      = $_[6];
    my $indent   = $_[7];
    my $tvalue   = $_[8];
    my $tabindex = $tab ? "tabindex=\"$tab\"" : '';
    $req = $req ? '<font color=#CC0000>&nbsp;* required</font>' : '';
    my @selected = @{$selected};
    my @tvalues  = defined($tvalue) ? @{$tvalue} : ();
    my $detail   = qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr class=no_border>);
    my $name          = 'stalking_options';
    my $row_class     = 'data0';
    my $label_class   = $form_class;
    my $item_class    = 'enabled';
    my $item_disabled = '';
    if ($override) {
	my $override_checked = $override eq 'checked' ? 'checked' : '';
	$detail .= qq(\n<td class=connect_top width='2%' valign=baseline style="padding-right: 0;"><input class=$form_class type=checkbox name=$name\_override value=1 $override_checked onclick="toggle_enabled('$name\_override','$name',['$name\_label','$name\_labels']);"></td><td class=connect_top width="2%" valign=baseline style="padding-left: 0;">&nbsp;Inherit&nbsp;&nbsp;</td>);
	$row_class = 'data1';
	$label_class .= '_disabled' if $override_checked;
	$item_class    = $override_checked ? 'disabled' : 'enabled';
	$item_disabled = $override_checked ? 'disabled' : '';
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<td class=$row_class>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>);
    if ($indent) {
	$detail .= "\n<td class=$form_class width='$indent_width' valign=top></td>";
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<td class=$label_class width="20%" name="$name\_label" id="$name\_label" valign=top>Stalking options: $req</td>);
    if ($doc) {
	$detail .=
	  "\n<td class=$form_class width='3%' valign=top align=center>\n<a class=orange href='#doc' title=\"$doc\" tabindex='-1'>&nbsp;?&nbsp;</a></td>";
    }
    else {
	$detail .= "\n<td class=$form_class width='3%' align=center>\n&nbsp;</td>";
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<td class=$label_class name=$name\_labels id="$name\_labels">);
    my @opts    = ();
    my %optname = ();
    if ( $obj =~ /^host/ ) {
	@opts = ( 'o', 'd', 'u' );
	%optname = ( o => 'up states', d => 'down states', u => 'unreachable states' );
    }
    elsif ( $obj =~ /^service/ ) {
	@opts = ( 'o', 'w', 'c', 'u' );
	%optname = ( o => 'okay states', w => 'warning states', c => 'critical states', u => 'unknown states' );
    }
    my $desc = undef;
    foreach my $opt (@opts) {
	$desc = $optname{$opt};
	my $got_opt = undef;
	my $got_raw = 0;
	foreach my $sel (@selected) {
	    if ( $sel eq $opt ) { $got_opt = 1 }
	}
	foreach my $raw (@tvalues) {
	    if ( $raw eq $opt ) { $got_raw = 1 }
	}
	my $value_checked = $got_opt ? 'checked' : '';
	my $alt = defined($tvalue) ? ( $got_raw ? 'alt="true"' : 'alt="false"' ) : "alt='\0'";
	$detail .= "\n<input class=$item_class type=checkbox name=$name value=$opt $value_checked $alt $item_disabled $tabindex>&nbsp;\u$desc $req<br>";
	$req = '';
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
</td>
</tr>
</table>
</td>
</tr>);
    return $detail;
}

sub notification_options(@) {
    my $obj        = $_[1];
    my $name       = $_[2];
    my $selected   = $_[3];
    my $req        = $_[4];
    my $nagios_ver = $_[5];
    my $doc        = $_[6];
    my $override   = $_[7];
    my $tab        = $_[8];
    my $indent     = $_[9];
    my $tvalue     = $_[10];
    my $tabindex   = $tab ? "tabindex=\"$tab\"" : '';
    $req = $req ? '<font color=#CC0000>&nbsp;* required</font>' : '';
    my @selected = @{$selected};
    my @tvalues  = defined($tvalue) ? @{$tvalue} : ();
    my $title    = $name;
    $title =~ s/_/ /g;
    my $detail = qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr class=no_border>);
    my $row_class     = 'data0';
    my $label_class   = $form_class;
    my $item_class    = 'enabled';
    my $item_disabled = '';
    if ($override) {
	my $override_checked = $override eq 'checked' ? 'checked' : '';
	$detail .= qq(\n<td class=connect_top width='2%' valign=baseline style="padding-right: 0;"><input class=$form_class type=checkbox name=$name\_override value=1 $override_checked onclick="toggle_enabled('$name\_override','$name',['$name\_label','$name\_labels']);"></td><td class=connect_top width="2%" valign=baseline style="padding-left: 0;">&nbsp;Inherit&nbsp;&nbsp;</td>);
	$row_class = 'data1';
	$label_class .= '_disabled' if $override_checked;
	$item_class    = $override_checked ? 'disabled' : 'enabled';
	$item_disabled = $override_checked ? 'disabled' : '';
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<td class=$row_class>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>);
    if ($indent) {
	$detail .= "\n<td class=$form_class width='$indent_width' valign=top></td>";
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<td class=$label_class width="20%" name="$name\_label" id="$name\_label" valign=top>\u$title:</td>);
    if ($doc) {
	$detail .=
	  "\n<td class=$form_class width='3%' valign=top align=center>\n<a class=orange href='#doc' title=\"$doc\" tabindex='-1'>&nbsp;?&nbsp;</a></td>";
    }
    else {
	$detail .= "\n<td class=$form_class width='3%' align=center>\n&nbsp;</td>";
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<td class=$label_class name="$name\_labels" id="$name\_labels">);
    my @opts = ();
    if ( $obj =~ /service_escalation/ ) {
	@opts = ( 'c', 'w', 'r', 'u' );
    }
    elsif ( $obj =~ /escalation/ ) {
	@opts = ( 'd', 'r', 'u' );
    }
    elsif ( $obj =~ /contact/ && $name =~ /service/ ) {
	@opts = ( 'c', 'w' );
	push @opts, 'f' if $nagios_ver =~ /^[23]\.x$/;
	push @opts, 'r', 'u';
	push @opts, 's' if $nagios_ver =~ /^[3]\.x$/;
	push @opts, 'n';
    }
    elsif ( $obj =~ /contact/ && $name =~ /host/ ) {
	@opts = ( 'd' );
	push @opts, 'f' if $nagios_ver =~ /^[23]\.x$/;
	push @opts, 'r', 'u';
	push @opts, 's' if $nagios_ver =~ /^[3]\.x$/;
	push @opts, 'n';
    }
    elsif ( $obj =~ /service/ ) {
	@opts = ( 'c', 'w' );
	push @opts, 'f' if $nagios_ver =~ /^[23]\.x$/;
	push @opts, 'r', 'u';
	push @opts, 's' if $nagios_ver =~ /^[3]\.x$/;
	push @opts, 'n';
    }
    elsif ( $obj =~ /host/ ) {
	@opts = ( 'd' );
	push @opts, 'f' if $nagios_ver =~ /^[23]\.x$/;
	push @opts, 'r', 'u';
	push @opts, 's' if $nagios_ver =~ /^[3]\.x$/;
	push @opts, 'n';
    }
    my $desc = undef;
    foreach my $opt (@opts) {
	if ( $opt eq 'd' ) {
	    $desc = 'down state';
	}
	elsif ( $opt eq 'c' ) {
	    $desc = 'critical state';
	}
	elsif ( $opt eq 'w' ) {
	    $desc = 'warning state';
	}
	elsif ( $opt eq 'f' ) {
	    $desc = 'flapping start or stop';
	}
	elsif ( $opt eq 'r' ) {
	    $desc = 'recovery (okay state)';
	}
	elsif ( $opt eq 'u' ) {
	    $desc = 'unreachable state';
	    if ( $obj =~ /service/ ) { $desc = 'unknown state' }
	    if ( $obj =~ /contact/ && $name =~ /service/ ) { $desc = 'unknown state' }
	}
	elsif ( $opt eq 's' ) {
	    $desc = 'scheduled downtime start or end';
	}
	elsif ( $opt eq 'n' ) {
	    $desc = 'none';
	}
	my $got_opt = undef;
	my $got_raw = 0;
	foreach my $sel (@selected) {
	    if ( $sel eq $opt ) { $got_opt = 1 }
	}
	foreach my $raw (@tvalues) {
	    if ( $raw eq $opt ) { $got_raw = 1 }
	}
	my $value_checked = $got_opt ? 'checked' : '';
	my $alt = defined($tvalue) ? ( $got_raw ? 'alt="true"' : 'alt="false"' ) : "alt='\0'";
	$detail .= "\n<input class=$item_class type=checkbox name=$name value=$opt $value_checked $alt $item_disabled $tabindex>&nbsp;\u$desc $req<br>";
	$req = '';
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
</td>
</tr>
</table>
</td>
</tr>);
    return $detail;
}

sub failure_criteria(@) {
    my $name     = $_[1];
    my $selected = $_[2];
    my $req      = $_[3];
    my $type     = $_[4];
    my $doc      = $_[5];
    my $override = $_[6];
    my $tab      = $_[7];
    my $tvalue   = $_[8];
    my $tabindex = $tab ? "tabindex=\"$tab\"" : '';
    $req = $req ? '<font color=#CC0000>&nbsp;* required</font>' : '';
    $type = '' if not defined $type;
    my @selected = @{$selected};
    my @tvalues  = defined($tvalue) ? @{$tvalue} : ();
    my $title    = $name;
    $title =~ s/_/ /g;
    my $detail = qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr class=no_border>);
    my $row_class     = 'data0';
    my $label_class   = $form_class;
    my $item_class    = 'enabled';
    my $item_disabled = '';
    if ($override) {
	my $override_checked = $override eq 'checked' ? 'checked' : '';
	$detail .= qq(\n<td class=connect_top width='2%' valign=baseline style="padding-right: 0;"><input class=$form_class type=checkbox name=$name\_override $override_checked onclick="toggle_enabled('$name\_override','$name',['$name\_label','$name\_labels']);" $tabindex></td><td class=connect_top width="2%" valign=baseline style="padding-left: 0;">&nbsp;Inherit&nbsp;&nbsp;</td>);
	$row_class = 'data1';
	$label_class .= '_disabled' if $override_checked;
	$item_class    = $override_checked ? 'disabled' : 'enabled';
	$item_disabled = $override_checked ? 'disabled' : '';
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<td class=$row_class>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>
<td class=$label_class width="20%" name="$name\_label" id="$name\_label" valign=top>\u$title:</td>);
    if ($doc) {
	$detail .=
	  "\n<td class=$form_class width='3%' valign=top align=center>\n<a class=orange href='#doc' title=\"$doc\" tabindex='-1'>&nbsp;?&nbsp;</a></td>";
    }
    else {
	$detail .= "\n<td class=$form_class width='3%' align=center>\n&nbsp;</td>";
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<td class=$label_class name=$name\_labels id="$name\_labels">);
    my @opts = ( 'o', 'w', 'u', 'c', 'n' );
    if ( $type eq 'host_dependencies' ) { @opts = ( 'o', 'd', 'u', 'p', 'n' ) }
    my $desc = undef;
    foreach my $opt (@opts) {
	if ( $opt eq 'o' && $type eq 'host_dependencies' ) {
	    $desc = 'up';
	}
	elsif ( $opt eq 'o' ) {
	    $desc = 'okay';
	}
	elsif ( $opt eq 'u' && $type eq 'host_dependencies' ) {
	    $desc = 'unreachable';
	}
	elsif ( $opt eq 'u' ) {
	    $desc = 'unknown';
	}
	elsif ( $opt eq 'd' ) {
	    $desc = 'down';
	}
	elsif ( $opt eq 'r' ) {
	    $desc = 'recovery';
	}
	elsif ( $opt eq 'c' ) {
	    $desc = 'critical';
	}
	elsif ( $opt eq 'w' ) {
	    $desc = 'warning';
	}
	elsif ( $opt eq 'p' ) {
	    $desc = 'pending';
	}
	elsif ( $opt eq 'n' ) {
	    $desc = 'none';
	}
	my $got_opt = undef;
	foreach my $sel (@selected) {
	    if ( $sel eq $opt ) { $got_opt = 1 }
	}
	my $value_checked = $got_opt ? 'checked' : '';
	## FIX MINOR:  define $alt appropriately, like in stalking_options()
	my $alt = '';
	$detail .= "\n<input class=$item_class type=checkbox name=$name value=$opt $value_checked $alt $item_disabled $tabindex>&nbsp;\u$desc $req<br>";
	$req = '';
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
</td>
</tr>
</table>
</td>
</tr>);
    return $detail;
}

sub submit_button(@) {
    my $name     = $_[1];
    my $value    = $_[2];
    my $tab      = $_[3];
    my $tabindex = $tab ? "tabindex=\"$tab\"" : '';
    return qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td valign=top class=data0 align=left>
<table cellpadding=5 cellspacing=0 border=0>
<tr>
<td class=$form_class>
<input class=submitbutton type=submit name=$name value="$value">
</td>
</tr>
</table>
</td>
</tr>);
}

sub form_top(@) {
    my $caption         = $_[1];
    my $onsubmit_action = $_[2];
    my $ez              = $_[3];
    my $boxwidth        = $_[4] || '100%';
    my $align           = 'left';
    if ( defined($ez) && $ez eq '1' ) { $cgi_exe = 'monarch_ez.cgi' }
    if ( defined($ez) && $ez eq '2' ) { $cgi_exe = 'monarch_auto.cgi' }
    $onsubmit_action = '' if not defined $onsubmit_action;
    return qq(@{[&$Instrument::show_trace_as_html_comment()]}
<form name=form action="$monarch_cgi/$cgi_exe" method=post $onsubmit_action generator=form_top>
<table width="$boxwidth" cellpadding=0 cellspacing=0 border=0 style="border-collapse: collapse; border-style: solid; border-width: 0;">
<tr>
<td class=data0 colspan=3>
<table width="100%" cellpadding=7 cellspacing=0 align=left border=0>
<tr>
<td class=head colspan=3>$caption</td>
</tr>
</table>
</td>
</tr>);
}

sub form_top_file(@) {
    my $caption         = $_[1];
    my $onsubmit_action = $_[2];
    my $ez              = $_[3];
    my $align           = 'left';

    # next line commented out because now the caller provides the ' onsubmit=' along with the action
    #if ($onsubmit_action) { $onsubmit_action = qq(@{[&$Instrument::show_trace_as_html_comment()]} onsubmit="$onsubmit_action") }
    if ($ez) { $cgi_exe = 'monarch_ez.cgi' }
    return qq(@{[&$Instrument::show_trace_as_html_comment()]}
<form name=form ENCTYPE="multipart/form-data" action="$monarch_cgi/$cgi_exe" method=post $onsubmit_action generator=form_top_file>
<table width="100%" cellpadding=0 cellspacing=0 border=0 style="border-collapse: collapse; border-style: solid; border-width: 0;">
<tr>
<td class=data0>
<table width="100%" cellpadding=7 cellspacing=0 align=left border=0>
<tr>
<td class=head colspan=3>$caption</td>
</tr>
</table>
</td>
</tr>);
}

sub form_errors(@) {
    my $errors = $_[1];
    my $errstr = join('<br>', @$errors);
    return qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=data0 colspan=3 id="errors">
<script type="text/javascript" language=JavaScript>
function SetErrorFocus() {
    document.getElementById('errors').scrollIntoView(false);
}
SafeAddOnload(SetErrorFocus);
</script>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>
<td class=error valign=top width="10%"><b>Error(s):</b></td>
<td class=error width="3%">&nbsp;</td>
<td class=error>
Please correct the following:<br>
$errstr
</td>
</tr>
</table>
</td>
</tr>);
}

sub profile_import_status(@) {
    my @messages     = @{ $_[1] };
    my $status_table = qq(@{[&$Instrument::show_trace_as_html_comment()]}
<table cellpadding=0 cellspacing=0 align=left border=0>);

    foreach my $message (@messages) {
	if ( $message =~ /^Importing/ ) {
	    $status_table .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=$form_class colspan=6>$message</td>
</tr><tr>
<td class=$form_class width="35%" align=left>&nbsp;</td>
<td class=$form_class width="13%" align=center>Read</td>
<td class=$form_class width="13%" align=center>Added</td>
<td class=$form_class width="13%" align=center>Updated</td>
<td class=$form_class width="13%" align=center>Overwrite</td>
<td class=$form_class width="13%" align=center>Errors</td>);
	}
	elsif ( $message =~ /^Performance/ ) {
	    $status_table .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
</tr><tr>
<td class=$form_class colspan=6>$message</td>);
	}
	elsif ( $message =~ /^-----/ ) {
	    $status_table .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
</tr><tr>
<td class=$form_class colspan=6><hr color="#000000"></td>);
	}
	elsif ( $message =~ /^(.*\S+)\s+(\d+)\s*read,\s*(\d+)\s*added,\s*(\d+)\s*updated\s*\(overwrite existing = (Y|N)\S+\)/ ) {
	    $status_table .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
</tr><tr>
<td class=$form_class valign=top align=left>$1</td>
<td class=$form_class valign=top align=center>$2</td>
<td class=$form_class valign=top align=center>$3</td>
<td class=$form_class valign=top align=center>$4</td>
<td class=$form_class valign=top align=center>$5</td>);
	}
	elsif (
	    $message =~ /^(.*\S+)\s+(\d+)\s*read,\s*(\d+)\s*added,\s*(\d+)\s*updated,\s*(\d+)\s*error[s]?\s*\(overwrite existing = (Y|N)\S+\)/ )
	{
	    $status_table .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
</tr><tr>
<td class=$form_class valign=top align=left>$1</td>
<td class=$form_class valign=top align=center>$2</td>
<td class=$form_class valign=top align=center>$3</td>
<td class=$form_class valign=top align=center>$4</td>
<td class=$form_class valign=top align=center>$6</td>
<td class=$form_class valign=top align=center>$5</td>);
	}
	elsif ( $message =~ /error|try again/i ) {
	    $status_table .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
</tr><tr>
<td class=error colspan=6>$message</td>);
	}
	else {
	    $status_table .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
</tr><tr>
<td class=$form_class colspan=6>$message</td>);
	}
    }

    $status_table .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
</tr>
</table>);

    return qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=data0>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>
<td class=wizard_title_heading style="padding: 0.5em 10px;" valign=top>Import Status:</td>
</tr>
<tr>
<td class=wizard_body>
<table width="100%" cellpadding=7 cellspacing=0 align=left border=0>
<tr>
<td class=wizard_body>$status_table</td>
</tr>
</table>
</td>
</tr>
</table>
</td>
</tr>);
}

sub form_message(@) {
    my $title         = $_[1];
    my $message       = $_[2];
    my $class         = $_[3];
    my $color_errors  = $_[4];
    my $simulate_tabs = $_[5];
    my $title_width   = $_[6] || '10%';
    my @message       = @{$message};
    # FIX LATER:  make $color_errors a pattern specified by the caller, not a binary flag
    if ($color_errors) {
	foreach (@message) {
	    s{.*}{<font color=#CC0000>$&</font>} if /Error:/i;
	}
    }
    if ($simulate_tabs) {
	foreach (@message) {
	    s/^(\t+)/'&nbsp;' x (length($1) * 8)/e;
	}
    }
    my $msg = join( '<br>', @message );
    return qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=data0>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>
<td class="$class" valign=top width="$title_width">$title</td>
<td class="$class" width="3%">&nbsp;</td>
<td class="$class">
$msg
</td>
</tr>
</table>
</td>
</tr>);
}

sub form_image(@) {
    my $image_file = $_[1];
    my $image_x    = $_[2];
    my $image_y    = $_[3];
    my $class      = $_[4];
    return qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=data0>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>
<td class="$class" align=center>
<img src="$image_file" width="$image_x" height="$image_y">
</td>
</tr>
</table>
</td>
</tr>);
}

sub form_doc(@) {
    my $message = $_[1];
    return qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=data0>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>
<td class=$form_class valign=top width="100%">
$message
</td>
</tr>
</table>
</td>
</tr>);
}

sub form_status(@) {
    my $title   = $_[1];
    my $message = $_[2];
    my $class   = $_[3];
    return qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=data0>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>
<td class="$class" valign=top width="10%">&nbsp;$title</td>
<td class="$class" colspan=2>
$message
</td>
</tr>
</table>
</td>
</tr>);
}

# FIX MINOR:  this is copied verbatim from MonarchAutoConfig.pm; refactor so we have only one common copy
sub js_utils() {
    return qq(
<script type="text/javascript" language=JavaScript>
    // GWMON-9658
    // use browser sniffing to determine if IE or Opera (ugly, but required)
    var isOpera = false;
    var isIE = false;
    if (typeof(window.opera) != 'undefined') {isOpera = true;}
    if (!isOpera && navigator.userAgent.indexOf('MSIE') >= 0) {isIE = true;}
    function open_window(url,name,features) {
	features = features || '';  // GWMON-10363
	if (isIE) {
	    var referLink = document.createElement('a');
	    referLink.href = url;
	    referLink.onclick = function () {
		var safe_url = location.protocol + '//' + location.host + "/portal-core/themes/groundwork/images/favicon.ico";
		window.open(safe_url,name,features);
	    }
	    referLink.target = name;
	    document.body.appendChild(referLink);
	    referLink.click();
	}
	else {
	    window.open(url,name,features);
	}
    }
</script>);
}

sub js_toggle_input() {
    return qq(
<script type="text/javascript" language=JavaScript>
    function toggle_enabled(cboxname, itemnames, labels, buttons) {
	var checked;
	var prev_chk;
	var prev_val;
	var prev_alt;
	var prev_data_alt;
	eval("checked = document.form." + cboxname + ".checked;");
	if (typeof(itemnames) == 'string') {
	    itemnames = [ itemnames ];
	}
	for (var itm=itemnames.length;--itm>=0;) {
	    var ideas = document.getElementsByName(itemnames[itm]);
	    for (var i=ideas.length;--i>=0;) {
		prev_chk      = ideas[i].checked;
		prev_val      = ideas[i].value;
		prev_alt      = ideas[i].alt;
		// prev_data_alt = ideas[i].dataset.alt;
		// getAttributes() is used instead of dataset for old-browser compatibility
		prev_data_alt = ideas[i].getAttribute("data-alt");
		if (checked && ideas[i].type == 'textarea' && prev_data_alt != "\0") {
		    ideas[i].value       = prev_data_alt;
		    // ideas[i].dataset.alt = prev_val;
		    // setAttributes() is used instead of dataset for old-browser compatibility
		    ideas[i].setAttribute("data-alt", prev_val);
		}
		if (checked && ideas[i].type == 'text' && prev_alt != "\0") {
		    ideas[i].value = prev_alt;
		    ideas[i].alt   = prev_val;
		}
		if (checked && ideas[i].type == 'checkbox' && prev_alt != "\0") {
		    ideas[i].checked = prev_alt == 'true' ? true : false;
		    ideas[i].alt     = prev_chk;
		}
		ideas[i].disabled  = checked;
		ideas[i].className = checked ? 'disabled' : 'enabled';
		if (!checked && ideas[i].type == 'textarea' && prev_data_alt != "\0") {
		    ideas[i].value       = prev_data_alt;
		    // ideas[i].dataset.alt = prev_val;
		    // setAttributes() is used instead of dataset for old-browser compatibility
		    ideas[i].setAttribute("data-alt", prev_val);
		}
		if (!checked && ideas[i].type == 'text' && prev_alt != "\0") {
		    ideas[i].value = prev_alt;
		    ideas[i].alt   = prev_val;
		}
		if (!checked && ideas[i].type == 'checkbox' && prev_alt != "\0") {
		    ideas[i].checked = prev_alt == 'true' ? true : false;
		    ideas[i].alt     = prev_chk;
		}
	    }
	}
	if (labels != undefined) {
	    if (typeof(labels) == 'string') {
		labels = [ labels ];
	    }
	    for (var lab=labels.length;--lab>=0;) {
		var ideas = document.getElementsByName(labels[lab]);
		for (var i=ideas.length;--i>=0;) {
		    ideas[i].className = ideas[i].className.replace(/(_disabled)?\$/, checked ? '_disabled' : '');
		}
	    }
	}
	if (buttons != undefined) {
	    if (typeof(buttons) == 'string') {
		buttons = [ buttons ];
	    }
	    for (var but=buttons.length;--but>=0;) {
		var ideas = [];
		if (buttons[but].match(/[*]/)) {
		    var pattern = new RegExp ('^' + buttons[but].replace(/[*]/, ''));
		    var maybe = document.body.getElementsByTagName('input');
		    for (var i=maybe.length;--i>=0;) {
			if (typeof(maybe[i].name) == 'string' && maybe[i].name.match(pattern)) {
			    ideas.push(maybe[i]);
			}
		    }
		}
		else {
		    ideas = document.getElementsByName(buttons[but]);
		}
		for (var i=ideas.length;--i>=0;) {
		    ideas[i].disabled  = checked;
		    ideas[i].className = ideas[i].className.replace(/(_disabled)?\$/, checked ? '_disabled' : '');
		}
	    }
	}
    }
    function toggle_options(cboxname, itemname, labels) {
	var checked;
	eval("checked = document.form." + cboxname + ".checked;");
	var altitemname = "_alt_" + itemname;
	var idea = document.getElementsByName(itemname)[0];
	var altidea = document.getElementsByName(altitemname)[0];
	if (checked) {
	    idea.style.display = 'none';
	    altidea.style.display = 'inline';
	}
	else {
	    idea.style.display = 'inline';
	    altidea.style.display = 'none';
	}
	if (labels != undefined) {
	    if (typeof(labels) == 'string') {
		labels = [ labels ];
	    }
	    for (var lab=labels.length;--lab>=0;) {
		var ideas = document.getElementsByName(labels[lab]);
		for (var i=ideas.length;--i>=0;) {
		    ideas[i].className = ideas[i].className.replace(/(_disabled)?\$/, checked ? '_disabled' : '');
		}
	    }
	}
    }
</script>);
}

sub form_bottom_buttons(@) {
    my $self_discard = shift;
    my @args         = @_;
    my $tab          = 0;
    if ( ref( $args[$#args] ) ne 'HASH' ) {
	$tab = pop(@args);
    }
    my $tabindex = $tab ? "tabindex=\"$tab\"" : '';
    my $class;
    my $disabled;
    my $type;
    my $onclick;
    my $html = js_utils();
    $html .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
    <tr>
    <td class=buttons colspan=3>
    <table width="100%" cellpadding=0 cellspacing=0 border=0>
    <tr>
    <td style=border:0 align=left>);

    foreach my $button (@args) {
	if (defined $button->{disabled}) {
	    $class = 'submitbutton_disabled';
	    $disabled = 'disabled';
	}
	else {
	    $class = 'submitbutton';
	    $disabled = '';
	}
	if ($button->{url}) {
	    $type = 'button';
	    $onclick = "open_window('$button->{url}')";
	}
	else {
	    $type = 'submit';
	    $onclick = ( $button->{onclick} // '' ) . ";this.form.clicked=this.name";
	}
	$html .= qq(
<input class=$class $disabled type=$type name=$button->{name} value="$button->{value}" onclick="$onclick" $tabindex>&nbsp;);
    }
    unindent($html);

    my $html_end = qq(@{[&$Instrument::show_trace_as_html_comment()]}
    </td>
    </tr>
    </table>
    </td>
    </tr>
    </table>
    </form>);
    unindent($html_end);

    return $html . $html_end;
}

sub form_file(@) {
    my $tab = $_[1];
    my $tabindex = $tab ? "tabindex=\"$tab\"" : '';
    return qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=data0>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>
<td class=$form_class>Upload&nbsp;file:
</td>
<td class=$form_class>
<input type=file name=upload_file size=70 maxlength=100 $tabindex>
</td>
</tr>
</table>
</td>
</tr>);
}

sub table_download_links(@) {
    my $doc_folder = $_[1];
    my @source     = @{ $_[2] };
    my $server     = $_[3];
    my $line_url;
    my $plain_url;
    my $detail = qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=data0>
<table width="100%" cellspacing=7 align=left border=0>
<tr>
<td class=wizard_title valign=top><b>Files in <code>$doc_folder</code></b></td>
</tr>
<tr>
<td class=wizard_body colspan=5>
<table width="100%" cellpadding=3 cellspacing=0 align=left border=0>
<tr>
<td class=column_head align=left style="width:auto">File with line numbers</td>
<td class=column_head align=left style="width:auto">Plain file</td>
<td class=column_head align=left style="width:55%"></td>
</tr>);

    my $row = 1;
    foreach my $name (@source) {
	my $class = undef;
	if ( $row == 1 ) {
	    $class = 'row_lt';
	    $row   = 2;
	}
	elsif ( $row == 2 ) {
	    $class = 'row_dk';
	    $row   = 1;
	}
	if ( $name =~ /tar$/ ) {
	    $line_url = '';
	    $plain_url  = qq(<a href="$monarch_export/$name"><b><code>$name</code></b></a>);
	}
	else {
	    $line_url  = qq(<a href="$monarch_cgi/monarch_file.cgi?file=$monarch_download/$name" target="_blank"><b><code>$name</code></b></a>);
	    $plain_url = qq(<a href="$monarch_export/$name" target="_blank"><b><code>(plain)</code></b></a>);
	}
	$detail .= qq(<tr>
		<td class=$class style="white-space:nowrap; width:auto">$line_url &nbsp;&nbsp;&nbsp;</td>
		<td class=$class style="white-space:nowrap; width:auto">$plain_url</td>
		<td class=$class></td>
		</tr>\n);
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
</table>
</td>
</tr>
</table>
</td>
</tr>
);
    return $detail;
}

sub success(@) {
    my $caption   = $_[1];
    my $message   = $_[2];
    my $task      = $_[3];
    my $hidden    = $_[4];
    my %hidden    = %{$hidden};
    my $hiddenstr = '';
    foreach my $name ( keys %hidden ) {
	unless ( $name =~ /HASH/ ) {
	    $hiddenstr .= "\n<input type=hidden name=$name value=\"" . (defined( $hidden{$name} ) ? $hidden{$name} : '') . "\">";
	}
    }
    return qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td valign=top>
<table width="100%" cellpadding=0 cellspacing=0 border=0 style="border-collapse: collapse; border-style: solid; border-width: 0;">
<tr>
<td class=data0>
<table width="100%" cellpadding=7 cellspacing=0 align=left border=0>
<tr>
<td class=head>$caption</td>
</tr>
</table>
</td>
</tr>
<tr>
<td class=data0>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>
<td class=$form_class>$message</td>
</tr>
</table>
</td>
</tr>
<tr>
<td style=border:0 align=left>
<form action="$monarch_cgi/$cgi_exe" generator=success>
$hiddenstr
<input class=submitbutton type=submit name=$task value="Continue">
</form>
</td>
</tr>
</table>
</td>
</tr>);
}

sub are_you_sure(@) {
    my $caption = $_[1];
    my $message = $_[2];
    my $task    = $_[3];
    my $hidden  = $_[4];
    my $bail    = $_[5];
    if ( $_[6] ) { $cgi_exe = 'monarch_auto.cgi' }
    my %hidden    = %{$hidden};
    my $hiddenstr = '';
    unless ($bail) { $bail = 'task' }

    foreach my $name ( keys %hidden ) {
	unless ( $name =~ /HASH/ ) {
	    $hiddenstr .= "\n<input type=hidden name=$name value=\"" . (defined($hidden{$name}) ? $hidden{$name} : '') . "\">";
	}
    }
    return qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td valign=top>
<table width="100%" cellpadding=0 cellspacing=0 border=0 style="border-collapse: collapse; border-style: solid; border-width: 0;">
<tr>
<td class=data0>
<table width="100%" cellpadding=7 cellspacing=0 align=left border=0>
<tr>
<td class=head>$caption</td>
</tr>
</table>
</td>
</tr>
<tr>
<td class=data0>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>
<td class=$form_class>$message</td>
</tr>
</table>
</td>
</tr>
<tr>
<td style=border:0 align=left>
<form action="$monarch_cgi/$cgi_exe" generator=are_you_sure>
$hiddenstr
<input class=submitbutton type=submit name=$task value="Yes">&nbsp;
<input class=submitbutton type=submit name=$bail value="No">
</form>
</td>
</tr>
</table>
</td>
</tr>);
}

sub display($) {
    my $name    = shift;
    my @words   = split( /_/, $name );
    my $display = undef;
    foreach my $word (@words) { $display .= "\u$word " }
    chop $display;
    return $display;
}

sub frame(@) {
    my $session_id = $_[1];
    my $top_menu   = $_[2];
    my $is_portal  = $_[3];
    my $ez         = $_[4];
    my $cols       = 'cols="25%,75%"';
    if ( $top_menu eq 'time_periods' ) {
	$cols = 'cols="18%,82%"';
    }
    $ez = '' if not defined $ez;
    if ($is_portal) {
	# FIX MINOR:  Drop references to gw.jquery.autoheight.js now that we fixed the problem via other means?
	return qq(@{[&$Instrument::show_trace_as_html_comment()]}
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Frameset//EN"
<html>
<head>
<title>Monarch</title>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
<script type="text/javascript" language=JavaScript src="$monarch_js/DataFormValidator.js"></script>
<script type="text/javascript" language=JavaScript src="$monarch_js/gw.jquery.autoheight.js"></script>
</head>
<script type="text/javascript" language=JavaScript>
    var isMSIE = /*\@cc_on!@*/false;
    var frameborder = isMSIE ? '0' : '1';
    document.write('<frameset $cols frameborder=1 border=2 framespacing=2 bordercolor="#000000">');
    document.write('<frame name="monarch_left" frameborder='+frameborder+' style="overflow: auto;" src="$monarch_cgi/monarch_tree.cgi?CGISESSID=$session_id&amp;top_menu=$top_menu&amp;ez=$ez">');
    document.write('<frame name="monarch_main" frameborder='+frameborder+' style="overflow: auto;" src="$monarch_html/cover.html" class="autoHeight">');
    document.write('</frameset>');
</script>
</html>);
    }
    else {
	return qq(@{[&$Instrument::show_trace_as_html_comment()]}
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Frameset//EN"
<html>
<head>
<title>Monarch</title>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
<script type="text/javascript" language=JavaScript src="$monarch_js/DataFormValidator.js"></script>
</head>
<script type="text/javascript" language=JavaScript>
    document.write('<frameset rows="73,*" cols="*" border=0 frameborder=0>');
    document.write('<frame name="monarch_top" scrolling="no" noresize src="$monarch_cgi/$cgi_exe?update_top=1&amp;CGISESSID=$session_id&amp;top_menu=hosts&amp;ez=$ez&amp;login=1">');
    document.write('<frameset $cols frameborder=1 border=2 framespacing=2 bordercolor="#000000">');
    var isMSIE = /*\@cc_on!@*/false;
    var frameborder = isMSIE ? '0' : '1';
    document.write('<frame name="monarch_left" frameborder='+frameborder+' style="overflow: auto;" src="$monarch_cgi/monarch_tree.cgi?CGISESSID=$session_id&amp;top_menu=$top_menu&amp;ez=$ez">');
    document.write('<frame name="monarch_main" frameborder='+frameborder+' style="overflow: auto;" src="$monarch_html/cover.html">');
    document.write('</frameset>');
    document.write('</frameset>');
</script>
</html>);
    }
}

sub top_frame(@) {
    my $session_id = $_[1];
    my $top_menu   = $_[2];
    my @menus      = @{ $_[3] };
    my $auth_level = $_[4];
    my $ver        = $_[5];
    my $enable_ez  = $_[6];
    my $ez         = $_[7];
    my %auth_add   = %{ $_[8] };
    my $login      = $_[9];
    local $_;

    my $title      = "GroundWork Monitor Architect";
    my $class      = 'submenu';
    my $links      = qq(@{[&$Instrument::show_trace_as_html_comment()]}
<td align=left>);
    my $colspan    = 2;
    my $menuspan   = 2;
    my $width      = 70;
    my $m          = 0;
    my $first_menu = $menus[0];
    foreach (@menus) { $m++ }
    if ($m) { $width = $width / $m }
    $width = sprintf( "%.0f", $width );
    my $javascript = '';
    my $ez_main    = '';
    my %selected   = ();

    if ($ez) {
	$selected{'ez'} = 'selected';
	$javascript = qq(parent.monarch_left.location='$monarch_cgi/monarch_tree.cgi?CGISESSID=$session_id&amp;top_menu=$top_menu&amp;ez=1';);
    }
    else {
	$selected{'main'} = 'selected';
	$javascript = qq(parent.monarch_left.location='$monarch_cgi/monarch_tree.cgi?CGISESSID=$session_id&amp;top_menu=$top_menu';);
    }
    if ($login) {
	$javascript = '';
    }    # don't want the page to load twice if new login
    if ( $enable_ez && ( $auth_add{'ez'} || $auth_add{'ez_main'} || $auth_add{'main_ez'} ) ) {
	$ez_main = qq(@{[&$Instrument::show_trace_as_html_comment()]}
<td class=top align=left width="5%">
<form name=form action="$monarch_cgi/$cgi_exe" method=post generator=top_frame>
<input type=hidden name=CGISESSID value=$session_id>
<input type=hidden name=top_menu value=$top_menu>
<input type=hidden name=update_top value=1>
<select name=ez onchange="lowlight();submit()">
<option $selected{'main'} value=0>Main</option>
<option $selected{'ez'} value=1>EZ</option>
</select>
</form>
</td>);
    }
    foreach my $menu (@menus) {
	$colspan++;
	$menuspan++;
	my $display = "\u$menu";
	if ( $menu =~ /_/ ) {
	    $display = undef;
	    my @disp = split( /_/, $menu );
	    foreach (@disp) { $display .= "\u$_ " }
	    chop $display;
	}
	$class = 'top_menu_menu';
	if ( $menu eq 'help' ) {
	    require MonarchStorProc;
	    my $help_url = StorProc->doc_section_url('Configuration');
	    $links .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<a class=top_frame href="$help_url" target="_blank">$display</a>);
	}
	else {
	    $links .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
&nbsp;<a class=top_frame href="$monarch_cgi/monarch_tree.cgi?CGISESSID=$session_id&amp;top_menu=$menu&amp;ez=$ez" target="monarch_left" onclick="load_main_frame();">$display</a>&nbsp;&nbsp;&nbsp;&nbsp;);
	}
    }
    $links .= "\n</td>";
    $width = "$width" . "%";
    my $logout = '';
    if ( $auth_level == 2 ) {
	$colspan--;
	$logout = qq(@{[&$Instrument::show_trace_as_html_comment()]}
<td class=head align=right>
<a class=head href="$monarch_cgi/$cgi_exe?CGISESSID=$session_id&amp;view=logout" target=_top>Log out</a>
</td>);
    }

    my $detail = qq(
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<html>
<head>@{[&$Instrument::show_trace_as_html_comment()]}
<title>Monarch Menus</title>
<meta http-equiv="X-UA-Compatible" content="IE=edge">
<META HTTP-EQUIV="CONTENT-TYPE" CONTENT="text/html; charset=utf-8">
<META HTTP-EQUIV="Pragma" CONTENT="no-cache">
<META HTTP-EQUIV="Expires" CONTENT="-1">
<link rel="stylesheet" type="text/css" href="$monarch_css/monarch.css">
<script type="text/javascript" language=JavaScript>
	function load_frames() {
		$javascript
		// parent.monarch_main.location.href = "$monarch_html/blank.html";
		return false;
	}
</script>
</head>
<body bgcolor="#ffffff" onload="load_frames()">
<!-- generated by: MonarchForms::top_frame() -->
<table width="100%" cellpadding=0 border=0 style="border-spacing: 0 2px;">
<tr>
<td>
<table width="100%" cellpadding=7 cellspacing=0 align=left border=0>
<tr>
<td class=head colspan=$colspan>&nbsp;<img src="$monarch_images/gw_logo.gif">&nbsp;&nbsp;$title $ver</td>
$logout
</tr>
</table>
</td>
</tr>
<tr>
<td class=row2>
<table width="100%" cellpadding=3 cellspacing=0 border=0>
<tr>
$ez_main
$links
</tr>
</table>
</td>
</tr>
</table>
</body>
<script type="text/javascript" language=JavaScript src="$monarch_js/DataFormValidator.js"></script>
</html>);
    return $detail;
}

sub header(@) {
    my $title        = $_[1];
    my $session_id   = $_[2];
    my $top_menu     = $_[3];
    my $refresh_url  = $_[4];
    my $refresh_left = $_[5];
    my $ez           = $_[6];
    my $load_event   = $_[7];
    if ( defined($ez) && $ez eq '1' ) { $cgi_exe = 'monarch_ez.cgi' }
    if ( defined($ez) && $ez eq '2' ) { $cgi_exe = 'monarch_auto.cgi' }
    my $meta = qq(<META HTTP-EQUIV="Expires" CONTENT="-1">);

    my $scripting  = '';
    my $javascript = '';
    my $now        = time;
    if ($refresh_url) {
	if ( $refresh_url =~ m{^(\?|http)} ) {
	    ## This meta-refresh used to be our standard mechanism for triggering a redirect after
	    ## displaying the current page, but it no longer works because we now insist on a referrer.
	    ## $meta = qq(<META HTTP-EQUIV="Refresh" CONTENT="0; URL=$refresh_url">);
	    $javascript = "onload=\"location='$refresh_url';\"";
	}
	else {
	    (my $quoted_data = $refresh_url) =~ s/\\/\\\\/g;
	    $quoted_data =~ s/"/\\"/g;
	    $quoted_data =~ s/\n/\\n/g;
	    $scripting = qq(
<script type="text/javascript" language=JavaScript>
function refresh_page() {
    var request = new XMLHttpRequest();
    request.onreadystatechange = function() {
	if (request.readyState == 4) {
	    var doc;
	    if (request.status == 200) {
		var content_type = request.getResponseHeader("Content-Type").replace(/;.*/, '');
		if (content_type == "text/html") {
		    doc = request.responseText;
		}
		else {
		    doc = "<html><body>HTTP request failure: the response has the wrong content type (" + content_type + ").</body></html>";
		}
	    }
	    else {
		doc = "<html><body>HTTP request failure (response code " + request.status + ": " + request.statusText + ").</body></html>";
	    }
	    // document.open();
	    document.write(doc);
	    document.close();
	}
    }
    request.open("POST", location.protocol + '//' + location.host + location.pathname);
    request.setRequestHeader("Content-Type", "application/x-www-form-urlencoded");
    request.send("$quoted_data");
}
</script>);

	    $javascript = "onload=\"refresh_page('$refresh_url');\"";
	}
    }
    elsif ($refresh_left) {
	my $ezstr = $ez ? '&ez=1' : '';
	$top_menu =~ s/\s/_/g;    # refresh left time Periods to time_periods
	$top_menu = lc($top_menu);
	$javascript =
"onload=\"parent.monarch_left.location='$monarch_cgi/monarch_tree.cgi?CGISESSID=$session_id&amp;nocache=$now&amp;refresh_left=1&amp;top_menu=$top_menu$ezstr';\"";
    }
    elsif ( defined($load_event) ) {
	if ( $load_event eq '1' ) {
	    $javascript = "onload=\"scan_host();\"";
	}
	elsif ( $load_event eq '2' ) {
	    $javascript = "onload=\"got_warning = false; got_error = false; check_status();\"";
	}
    }
    return qq(
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<html>
<head>@{[&$Instrument::show_trace_as_html_comment()]}
<title>$title</title>
<meta http-equiv="X-UA-Compatible" content="IE=edge">
<META HTTP-EQUIV="CONTENT-TYPE" CONTENT="text/html; charset=utf-8">
<META HTTP-EQUIV="Pragma" CONTENT="no-cache">
$meta
<link rel="stylesheet" type="text/css" href="$monarch_css/monarch.css">
<script type="text/javascript" language=javascript1.1 src="$monarch_js/monarch.js"></script>
<script type="text/javascript" language=JavaScript src="$monarch_js/nicetitle.js"></script>
<script type="text/javascript" language=JavaScript src="$monarch_js/DataFormValidator.js"></script>
$scripting
</head>
<body bgcolor="#ffffff" $javascript>);
}

# FIX MAJOR:  make sure the table tags used here are always matched by corresponding tags earlier
sub footer(@) {
    my $debug = $_[1];
    $debug = '' if not defined $debug;
    return qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td>
$debug
$extend_page
</td>
</tr>
</table>
</body>
</html>);
}

############################################################################
# Special Forms
#

sub access_checkbox_list(@) {
    my $title    = $_[1];
    my $name     = $_[2];
    my @list     = @{ $_[3] };
    my @selected = @{ $_[4] };
    my $uc       = $_[5];
    my $detail   = qq(@{[&$Instrument::show_trace_as_html_comment()]}
<script type="text/javascript" language=JavaScript>
function doCheckAll()
{
  with (document.form) {
    for (var i=0; i < elements.length; i++) {
	if (elements[i].type == 'checkbox' && elements[i].id == 'asset_checked')
	   elements[i].checked = true;
    }
  }
}
function doUnCheckAll()
{
  with (document.form) {
    for (var i=0; i < elements.length; i++) {
	if (elements[i].type == 'checkbox' && elements[i].id == 'asset_checked')
	   elements[i].checked = false;
    }
  }
}
</script>
<tr>
<td class=data0>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>
<td class=$form_class width="20%" valign=top>$title</td>
<td class=$form_class width='3%' align=center>&nbsp;</td>
<td class=$form_class>);
    my $got_selected = undef;
    foreach my $item (@list) {
	my $element = $item;
	$element =~ s/_/ /g;
	$element = "\u$element" if $uc;
	foreach my $selected (@selected) {
	    if ( $item eq $selected ) { $got_selected = 1 }
	}
	if ($got_selected) {
	    $got_selected = undef;
	    $detail .= "\n<input class=$form_class type=checkbox name=$name id=asset_checked value=\"$item\" checked>&nbsp;$element<br>";
	}
	else {
	    $detail .= "\n<input class=$form_class type=checkbox name=$name id=asset_checked value=\"$item\">&nbsp;$element<br>";
	}
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
</td>
</tr>
</table>
</td>
</tr>
<tr>
<td>
<table width="100%" cellpadding=0 cellspacing=0 align=left border=0>
<tr>
<td>
<input type=submit class=submitbutton name=update_access value="Save">&nbsp;&nbsp;
<input class=submitbutton type=button value="Check All" onclick="doCheckAll();">&nbsp;&nbsp;
<input class=submitbutton type=button value="Uncheck All" onclick="doUnCheckAll();">&nbsp;&nbsp;
<input type=submit class=submitbutton name=close value="Close">
</td>
</tr>
</form>
</table>
</td>
</tr>);
    return $detail;
}

sub access_settings_ez(@) {
    my %view = %{ $_[1] };
    if ( $view{'enable_ez'} ) { $view{'enable_ez'}       = 'checked' }
    if ( $view{'ez_main'} )   { $view{'ez_main_checked'} = 'checked' }
    if ( $view{'main_ez'} )   { $view{'main_ez_checked'} = 'checked' }
    if ( $view{'ez'} )        { $view{'ez_checked'}      = 'checked' }
    my $detail = qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=data0>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>
<td class=$form_class width="20%" valign=top>Enable EZ:</td>
<td class=$form_class width='3%' align=center>&nbsp;</td>
<td class=$form_class>
<input class=$form_class type=checkbox name=enable_ez value=enable_ez $view{'enable_ez'}>&nbsp;Enable<br>
</td>
</tr>
</table>
</td>
</tr>
<tr>
<td class=data0>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>
<td class=$form_class width="20%" valign=top>View option:</td>
<td class=$form_class width='3%' align=center>&nbsp;</td>
<td class=$form_class>
<input class=$form_class type=radio name=ez_view value=ez_main $view{'ez_main_checked'}>&nbsp;EZ-Main<br>
<input class=$form_class type=radio name=ez_view value=main_ez $view{'main_ez_checked'}>&nbsp;Main-EZ<br>
<input class=$form_class type=radio name=ez_view value=ez $view{'ez_checked'}>&nbsp;EZ<br>
</td>
</tr>
</table>
</td>
</tr>);
    return $detail;
}

sub access_list(@) {
    my $title           = $_[1];
    my $assets          = $_[2];
    my @assets          = @{$assets};
    my $assets_selected = $_[3];
    my %assets_selected = %{$assets_selected};
    my $type            = $_[4];
    local $_;

    my $detail = qq(@{[&$Instrument::show_trace_as_html_comment()]}
<script type="text/javascript" language=JavaScript>
function doCheckAll()
{
  with (document.form) {
    for (var i=0; i < elements.length; i++) {
	if (elements[i].type == 'checkbox' && elements[i].id == 'asset_checked')
	   elements[i].checked = true;
    }
  }
}
function doUnCheckAll()
{
  with (document.form) {
    for (var i=0; i < elements.length; i++) {
	if (elements[i].type == 'checkbox' && elements[i].id == 'asset_checked')
	   elements[i].checked = false;
    }
  }
}
</script>
<tr>
<td class=data0>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>
<td class=row2 align=left>&thinsp;<b>$title</b></td>
<td class=row2 align=center width="7%"><b>Add</b></td>
<td class=row2 align=center width="7%"><b>Modify</b></td>
<td class=row2 align=center width="7%"><b>Delete</b></td>
<td class=row2 width="50%">&nbsp;</td>
</tr>);

    foreach my $asset (@assets) {
	my %selected = {};
	my @perms = split( /,/, $assets_selected{$asset} );
	foreach (@perms) { $selected{$_} = " checked" }
	my $title = $asset;
	$title =~ s/_/ /g;
	$detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=$form_class>\u$title:</td>
<td class=$form_class align=center width="7%">
<input class=$form_class type=checkbox name=$type-add-$asset id=asset_checked value=1$selected{'add'}>
</td>
<td class=$form_class align=center width="7%">
<input class=$form_class type=checkbox name=$type-modify-$asset id=asset_checked value=1$selected{'modify'}>
</td>
<td class=$form_class align=center width="7%">
<input class=$form_class type=checkbox name=$type-delete-$asset id=asset_checked value=1$selected{'delete'}>
</td>
<td class=$form_class width="50%">&nbsp;</td>
</tr>);
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
</table>
</td>
</tr>
<tr>
<td>
<table width="100%" cellpadding=0 cellspacing=0 align=left border=0>
<tr>
<td>
<input type=submit class=submitbutton name=update_access value="Save">&nbsp;&nbsp;
<input class=submitbutton type=button value="Check All" onclick="doCheckAll();">&nbsp;&nbsp;
<input class=submitbutton type=button value="Uncheck All" onclick="doUnCheckAll();">&nbsp;&nbsp;
<input type=submit class=submitbutton name=close value="Close">
</td>
</tr>
</form>
</table>
</td>
</tr>);
    return $detail;
}

sub add_file() {
    my $name  = $_[1];
    my $type  = $_[2];
    my $path  = $_[3];
    my $files = $_[4];
    my $file  = $_[5];
    my $req   = $_[6];
    my $doc   = $_[7];
    $req = $req ? '<font color=#CC0000>&nbsp;* required</font>' : '';

    my @files = @{$files};
    my $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=data0>
<table width="100%" cellpadding=5 cellspacing=0 align=left border=0>
<tr>
<td class=$form_class align=left width="10%">File:</td>

<td class=$form_class align=left>
<select name=file>);
    if ( !$files[0] ) {
	$detail .= "\n<option selected value=''></option>";
	$detail .= "\n<option value=''>-- no check commands --</option>";
    }
    else {
	if ($name) {
	    $detail .= "\n<option value=''></option>";
	}
	else {
	    $detail .= "\n<option selected value=''></option>";
	}
	foreach my $item (@files) {
	    if ( $item eq $name ) {
		$detail .= "\n<option selected value=\"$item\">$item</option>";
	    }
	    else {
		$detail .= "\n<option value=\"$item\">$item</option>";
	    }
	}
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
</select>
$req
</td>
<td class=$form_class width="1%">&nbsp;</td>

<tr>
<td class=$form_class width="10%">&nbsp;
<input type=hidden name=type value=$type>
</td>
<td class=$form_class>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>
<td class=$form_class align=left width="15%"><input class=submitbutton type=submit name=add_file value="Add New File">
<td class=$form_class align=left width="10%">File:</td>
<td class=$form_class align=left width="75%"><input type=text size=60 name=new_file value="$file"> $req</td>
</tr>
<tr>
<td class=$form_class align=left width="15%">&nbsp;</td>
<td class=$form_class align=left width="10%">Path:</td>
<td class=$form_class align=left width="75%"><input type=text size=80 name=path value="$path"> $req</td>
</tr>
</table>
<td class=$form_class width="1%">&nbsp;</td>
</td>
</tr>
<tr>
<td class=$form_class colspan=3>&nbsp;</td>
</tr>
</table>
</td>
</tr>);
    return $detail;
}

sub external_list(@) {
    my $session_id   = $_[1];
    my $name         = $_[2];
    my $externals    = $_[3];
    my $list         = $_[4];
    my $type         = $_[5];
    my $service_id   = $_[6];  # not used; drop this, here and in all callers?
    my $service_name = $_[7];  # not used; drop this, here and in all callers?
    my $modified     = $_[8];
    my $obj_view     = 'host_externals';
    if ( $type eq 'service' ) { $obj_view = 'service_externals' }
    my %externals = %{$externals};
    my @list      = @{$list};
    my $detail    = undef;
    ( my $short_type = $type ) =~ s/_name//;

    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=data2>
<table width="100%" cellpadding=0 cellspacing=7 align=left border=0>
<tr>
<td class=data2>
<table class=form width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>
<td class=column_head colspan=4>\u$short_type External Details &hellip;</td>
</tr>);
    my $row = 1;
    foreach my $external ( sort keys %externals ) {
	my $class = undef;
	my $removebutton = undef;
	if ( $row == 1 ) {
	    $class = 'row_lt';
	    $removebutton = 'removebutton_lt';
	    $row   = 2;
	}
	elsif ( $row == 2 ) {
	    $class = 'row_dk';
	    $removebutton = 'removebutton_dk';
	    $row   = 1;
	}
	if ( $external =~ /HASH/ ) { next }
	my $lexternal = $external;
	$lexternal =~ s/\s/+/g;
	if ( $type eq 'service_name' ) {
	    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class="$class" width="80%" align=left>
$external
</td>);
	}
	else {
	    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class="$class" width="40%" align=left>
<input class="$removebutton" type=submit name=select_external value="$external">
</td>);
	}
	my $modify_state = !$modified ? '' : $modified->{$external} ? 'locally modified' : 'unmodified from original';
	$detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<td class="$class" width="40%" align=left>
$modify_state
</td>
<td class="$class" align=center>
<input class="$removebutton" type=submit name=remove_external_$externals{$external} value="remove">
</td>
</tr>);
    }
    my $size = ( scalar @list ) + 1;
    $size = 20 if $size > 20;
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
</table>
</td>
</tr>
<tr>
<td class=data2>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>

<!--
<td class=row2>
<table width="100%" cellpadding=3 cellspacing=0 border=0>
<tr>
-->

<td class=row2 width="30%"></td>
<td class=row2 align=right>
<select name=external size=$size>);
    if ( !$list[0] ) {
	$detail .= "\n<option value=''>-- no external names to add --</option>";
    }
    $detail .= "\n<option selected value=''></option>";
    @list = sort { lc($a) cmp lc($b) } @list;
    foreach my $item (@list) {
	$detail .= "\n<option value=\"$item\">$item</option>";
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
</select>&nbsp;&nbsp;
</td>
<td class=row2 align=left><input class=submitbutton type=submit name=external_add value="Add External"></td>
<td class=row2 width="30%"></td>
</tr>
</table>
</td>
</tr>
</table>
</td>
</tr>);
    return $detail;
}

sub external_xml_list(@) {
    my %externals = %{ $_[1] };
    my @externals = @{ $_[2] };
    my $detail    = qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=data0>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>);

    foreach my $ext ( sort keys %externals ) {
	if ( $ext =~ /^HASH/ ) { next }
	my $checked = undef;
	if ( $externals{$ext}{'enable'} eq 'ON' ) { $checked = 'checked' }
	$detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=$form_class width="20%" colspan=2><b>$ext</b></td>
<td class=$form_class>Enabled:</td>
<td class=$form_class colspan=4><input type=checkbox name=enabled value=$externals{$ext}{'id'} $checked></td>
</tr>);

	if ( $externals{$ext}{'description'} ) {
	    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=$form_class width="10%">&nbsp;</td>
<td class=$form_class>Enabled:</td>
<td class=$form_class colspan=5>$externals{$ext}{'description'}</td>
</tr>);

	}
	if ( $externals{$ext}{'service_name'} ) {
	    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=$form_class width="10%">&nbsp;</td>
<td class=$form_class colspan=4>$externals{$ext}{'service_name'}</td>
</tr>);

	}
	if ( $externals{$ext}{'command'} ) {
	    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=$form_class width="10%">&nbsp;</td>
<td class=$form_class width="10%">Command:</td>
<td class=$form_class colspan=4>$externals{$ext}{'command'}{'name'}</td>
</tr>);
	    foreach my $param ( sort keys %{ $externals{$ext}{'command'} } ) {
		if ( $param eq 'name' ) { next }
		$detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=$form_class width="10%">&nbsp;</td>
<td class=$form_class width="10%">&nbsp;&nbsp;Param:</td>
<td class=$form_class>$param</td>);
		if ( $externals{$ext}{'command'}{$param}{'description'} ) {
		    $detail .=
"\n<td class=$form_class valign=top align=left>\n<a class=orange href='#doc' title=\"$externals{$ext}{'command'}{$param}{'description'}\">&nbsp;?&nbsp;</a>";
		}
		else {
		    $detail .= "</td>\n<td class=$form_class width='3%' align=left>\n&nbsp;</td>";
		}
		$detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<td class=$form_class><input type=text size=50 name=param_value value="$externals{$ext}{'command'}{$param}{'value'}"></td>
</tr>);
	    }
	}
    }

    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
</table>
</td>
</tr>
<tr>
<td class=data0>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>
<td class=$form_class align=right><input class=submitbutton type=submit name=submit value="Add External(s)">
</td>
<td class=$form_class align=left>
<select name=external size=4 multiple>);
    if ( !$externals[0] ) {
	$detail .= "\n<option value=''>-- no external names to add --</option>";
    }
    $detail .= "\n<option selected value=''></option>";
    @externals = sort { lc($a) cmp lc($b) } @externals;
    foreach my $item (@externals) {
	$detail .= "\n<option value=\"$item\">$item</option>";
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
</select>&nbsp;&nbsp;
</td>
</tr>
</table>
</td>
</tr>);
    return $detail;
}

sub service_list(@) {
    my $session_id = $_[1];
    my $name       = $_[2];
    my $services   = $_[3];
    my $list       = $_[4];
    my $selected   = $_[5];
    my %services   = %{$services};
    my @list       = @{$list};
    my $now        = time;
    my $detail     = qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=data2>
<table width="100%" cellpadding=0 cellspacing=7 align=left border=0>
<tr>
<td class=data2>
<table class=form width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>
<td class=column_head colspan=2>&nbsp;Service Details &hellip;</td>
</tr>);
    my $row = 1;
    use URI::Escape;
    $name = uri_escape($name);

    foreach my $service ( sort keys %services ) {
	my $class = undef;
	if ( $row == 1 ) {
	    $class = 'row_lt';
	    $row   = 2;
	}
	elsif ( $row == 2 ) {
	    $class = 'row_dk';
	    $row   = 1;
	}
	if ( $service =~ /HASH/ ) { next }
	my $display = $service;
	$display =~ s/\+/ /g;
	$detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class="$class" align=left>
<a class=action href="$monarch_cgi/$cgi_exe?update_main=1&amp;CGISESSID=$session_id&amp;top_menu=hosts&amp;nocache=$now&amp;selected=$name&amp;view=manage_host&amp;obj=hosts&amp;obj_view=service_detail&amp;name=$name&amp;service_name=$service&amp;service_id=$services{$service}">
&nbsp;&nbsp;$display&nbsp;&nbsp;</a>
</td>
<td class="$class" align=center>
<a class=action href="$monarch_cgi/$cgi_exe?update_main=1&amp;CGISESSID=$session_id&amp;top_menu=hosts&amp;nocache=$now&amp;selected=$name&amp;view=manage_host&amp;obj=hosts&amp;obj_view=services&amp;name=$name&amp;service_id=$services{$service}&amp;submit=remove_service">&nbsp;&nbsp;remove service assignment&nbsp;&nbsp;</a>
</td>
</tr>);
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
</table>
</td>
</tr>
<tr>
<td class=data2>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>
<td class=row2 width="30%"></td>
<td class=row2 align=right>
<select name=add_service size=15 multiple>);
    if ( !$list[0] ) {
	$detail .= "\n<option value=''>-- no service names to add --</option>";
    }
    $detail .= "\n<option selected value=''></option>";
    @list = sort { lc($a) cmp lc($b) } @list;
    foreach my $item (@list) {
	$detail .= "\n<option value=\"$item\">$item</option>";
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
</select>&nbsp;&nbsp;
</td>
<td class=row2 align=left><input class=submitbutton type=submit name=submit value="Add Service(s)"></td>
<td class=row2 width="30%"></td>
</tr>
</table>
</td>
</tr>
</table>
</td>
</tr>);
    return $detail;
}

sub service_select(@) {
    my $services = $_[1];
    my $selected = $_[2];
    my $tab      = $_[3];
    my $tabindex = $tab ? "tabindex=\"$tab\"" : '';
    my %services = %{$services};
    my %selected = %{$selected};
    my $detail   = qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=data>
<table width="100%" cellpadding=7 cellspacing=0 align=left border=0>
<tr>
<td class=data>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>
<td class=column_head align=center colspan=3 style="white-space: nowrap;">Include/Modify/Discard</td>
<td class=column_head align=left>Service Name</td>
<td class=column_head align=left>Template</td>
<td class=column_head align=left>Extended Info</td>
</tr>);
    my $row = 1;

    foreach my $service ( sort keys %services ) {
	my $class = undef;
	if ( $row == 1 ) {
	    $class = 'row_lt';
	    $row   = 2;
	}
	elsif ( $row == 2 ) {
	    $class = 'row_dk';
	    $row   = 1;
	}

	if ( $service =~ /HASH/ ) { next }
	my %checked = (
	    add     => '',
	    edit    => '',
	    discard => ''
	);
	if ( $selected{$service} eq 'add' ) {
	    $checked{'add'} = 'checked';
	}
	elsif ( $selected{$service} eq 'edit' ) {
	    $checked{'edit'} = 'checked';
	}
	else {
	    $checked{'discard'} = 'checked';
	}
	my $title = $service;
	my $extinfo = defined( $services{$service}{'extinfo'} ) ? $services{$service}{'extinfo'} : '';
	$detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class="$class" rowspan=2 align=center width="5%">
<input type=radio class="$class" name="$service" value=add $checked{'add'} $tabindex>
</td>
<td class="$class" rowspan=2 align=center width="5%">
<input type=radio class="$class" name="$service" value=edit $checked{'edit'} $tabindex>
</td>
<td class="$class" rowspan=2 align=center width="5%">
<input type=radio class="$class" name="$service" value=discard $checked{'discard'} $tabindex>
</td>
<td class="$class" align=left>$title
</td>
<td class="$class" align=left>$services{$service}{'template'}
</td>
<td class="$class" align=left>$extinfo
</td>
</tr>
<tr>
<td class="$class" colspan=4 align=left>Check command: $services{$service}{'command'}
</td>
</tr>);
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<!--
<tr>
<td class=row3 colspan=2 align=left>&nbsp;</td>
</tr>
-->
</table>
</td>
</tr>
</table>
</td>
</tr>);
    return $detail;
}

sub profile_list(@) {
    my $session_id = $_[1];
    my $host       = $_[2];
    my $profiles   = $_[3];
    my @profiles   = @{$profiles};
    my $now        = time;
    my $detail     = qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=data3>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>
<td class=$form_class colspan=2>Service Profiles:</td>
</tr>
<tr>
<td class=row_lt>
<table width="100%" cellspacing=0 cellpadding=3 align=left border=0>);
    my $row = 1;

    if ( $profiles[0] ) {
	foreach my $profile (@profiles) {
	    my $class = undef;
	    my $removebutton = undef;
	    if ( $row == 1 ) {
		$class = 'row_lt';
		$removebutton = 'removebutton_lt';
		$row   = 2;
	    }
	    elsif ( $row == 2 ) {
		$class = 'row_dk';
		$removebutton = 'removebutton_dk';
		$row   = 1;
	    }
	    my $display = $profile;
	    $profile = uri_escape($profile);
	    $display =~ s/\+/ /g;
	    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class="$class" align=left>
$display
</td>
<td class="$class" align=center>
<input type=hidden name=profiles value=$profile>
<input class="$removebutton" type=submit name=remove_$profile value="remove profile" tabindex='-1'>
</td>
</tr>);
	}
    }
    else {
	$detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=row_lt align=left>
None selected
</td>
<td class=row_lt align=center>
&nbsp;
</td>
</tr>);

    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
</table>
</td>
</tr>

<!--
<tr>
<td class=$form_class align=center>&nbsp;</td>
</tr>
-->

</table>
</td>
</tr>);
    return $detail;
}

sub add_service_profile(@) {
    my $list     = $_[1];
    my $tab      = $_[2];
    my $tabindex = $tab ? "tabindex=\"$tab\"" : '';
    my @list     = @{$list};
    my $detail   = qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=data2>
<!-- this table is balanced out in add_service() -->
<table width="100%" cellpadding=0 cellspacing=7 border=0>
<tr>
<td class=data2>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>
<td class=row2_padded width="20%" align=left>Select service profile:
</td>
<td class=row2 align=left>
<select name=profiles $tabindex>);
    if ( !$list[0] ) {
	$detail .= "\n<option value=''>-- no service profiles to add --</option>";
    }
    $detail .= "\n<option selected value=''></option>";
    @list = sort { lc($a) cmp lc($b) } @list;
    foreach my $item (@list) {
	$detail .= "\n<option value=\"$item\">$item</option>";
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
</select>
</td>
<td class=row2 align=left>&nbsp;&nbsp;
</td>
<td class=row2 align=left><input class=submitbutton type=submit name=add_profile value="Add Profile" $tabindex>
</td>
<td class=row2 width="30%" align=left>&nbsp;</td>
</tr>
</table>
</td>
</tr>);
    return $detail;
}

sub add_service(@) {
    my $list     = $_[1];
    my $tab      = $_[2];
    my $tabindex = $tab ? "tabindex=\"$tab\"" : '';
    my @list     = @{$list};
    my $size     = ( scalar @list ) + 1;
    $size = 20 if $size > 20;
    my $detail = qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=data2>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>
<td class=row2_padded width="20%" align=left>Select other service(s):
</td>
<td class=row2 align=left>
<select name=services size=$size multiple $tabindex>);

    if ( !$list[0] ) {
	$detail .= "\n<option value=''>-- no services to add --</option>";
    }
    $detail .= "\n<option selected value=''></option>";
    @list = sort { lc($a) cmp lc($b) } @list;
    foreach my $item (@list) {
	$detail .= "\n<option value=\"$item\">$item</option>";
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
</select>
</td>
<td class=row2 align=left>&nbsp;&nbsp;
</td>
<td class=row2 align=left><input class=submitbutton type=submit name=add_service value="Add to list" $tabindex>
</td>
<td class=row2 width="38%" align=left>&nbsp;</td>
</tr>
</table>
</td>
</tr>
</table>
</td>
</tr>);
    return $detail;
}

sub manage_escalation_tree(@) {
    my $session_id     = $_[1];
    my $view           = $_[2];
    my $type           = $_[3];
    my $name           = $_[4];
    my $tree_id        = $_[5];
    my $ids            = $_[6];
    my $members        = $_[7];
    my $nonmembers     = $_[8];
    my $contact_groups = $_[9];
    my $first_notify   = $_[10];
    my $tab            = $_[11];
    my $tabindex       = $tab ? "tabindex=\"$tab\"" : '';
    my @members        = @{$members};
    my @nonmembers     = @{$nonmembers};
    @nonmembers = sort { lc($a) cmp lc($b) } @nonmembers;
    my %ids            = %{$ids};
    my %contact_groups = %{$contact_groups};
    my %first_notify   = %{$first_notify};
    my $errstr         = undef;
    my $now            = time;
    my $detail         = qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=data2>
<table width="100%" cellpadding=0 cellspacing=7 align=left border=0>
<tr>
<td class=data2 width="40%" colspan=2 align=left>
<table class=form cellspacing=0 cellpadding=3 width="100%" align=left border=0>
<tr>
<td class=column_head>Escalations</td>
<td class=column_head>First Notify</td>
<td class=column_head>Contact Groups</td>
<td class=column_head colspan=2>&nbsp;</td>
</tr>);

    my $row = 1;
    foreach my $escalation (@members) {
        my $class = undef;
        if ( $row == 1 ) {
            $class = 'row_lt';
            $row   = 2;
        }
        elsif ( $row == 2 ) {
            $class = 'row_dk';
            $row   = 1;
        }
	my $sname = $name;
	$sname =~ s/\s/+/g;
	my $fn = $first_notify{ $ids{$escalation} };
	$fn =~ s/-zero-/0/;
	my $contactgroups = $contact_groups{ $ids{$escalation} } || '<font color=#CC0000>ERROR: none assigned yet</font>';
	$detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=$class valign=top>
$escalation
</td>
<td class=$class valign=top>
$fn
</td>
<td class=$class>$contactgroups
</td>
<td class=$class align=center valign=top>
<input type=submit class=escbutton name=assign_contact_group_$ids{$escalation} value="modify contact groups" $tabindex>
</td>
<td class=$class align=center valign=top>
<input type=submit class=escbutton name=remove_escalation_$ids{$escalation} value="remove escalation" $tabindex>
</td>
</tr>);
    }

    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
</table>
</td>
</tr>
<tr>
<td class=row2 colspan=5>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 border=0>
<tr>
<td class=row2_padded width="20%" valign=top align=left>Potential escalations in this escalation tree:
</td>
<td class=row2 valign=top align=center>
<select name=escalation size=15 $tabindex>);
    my $options = undef;
    $detail .= "\n<option selected value=''></option>";
    foreach my $nmem (@nonmembers) {
	my $got_mem = undef;
	foreach my $mem (@members) {
	    if ( $nmem eq $mem ) { $got_mem = 1 }
	}
	if ($got_mem) {
	    $got_mem = undef;
	    next;
	}
	else {
	    $options .= "\n<option value=\"$nmem\">$nmem</option>";
	}
    }
    if ( !$options ) {
	$options = "\n<option value=''>-- no escalations --</option>";
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
$options
</select>&nbsp;&nbsp;
</td>
<td class=row2 width="55%" align=left><input class=submitbutton type=submit name=add_escalation value="Add Escalation" $tabindex>
</td>
</tr>
</table>
</td>
</tr>
</table>
</td>
</tr>);
}

sub host_top(@) {
    my $name         = $_[1];
    my $session_id   = $_[2];
    my $obj_view     = $_[3];
    my $externals    = $_[4];
    my $selected     = $_[5];
    my $form_service = $_[6];
    local $_;

    my $boxwidth = ( $obj_view eq 'service_check' || $obj_view =~ /_external_detail/ ) ? '100%' : '100%';
    my $now      = time;
    my $colspan  = 1;
    my @menus    = ();
    if ($form_service) {
	@menus   = ( 'service_detail', 'service_check', 'service_dependencies' );
	if ($externals) {
	    push @menus, 'service_externals';
	}
	if ( $obj_view eq 'service_external_detail' ) {
	    push @menus, 'service_external_detail';
	}
    }
    else {
	push @menus, 'host_detail';
	if ( $obj_view =~ /service_detail|service_dependencies|service_externals|service_check/ ) {
	    push( @menus, ( 'services', 'service_detail', 'service_check', 'service_dependencies' ) );
	    if ($externals) {
		push @menus, 'service_externals';
	    }
	}
	elsif ( $obj_view eq 'service_external_detail' ) {
	    push( @menus, ( 'services', 'service_detail', 'service_externals', 'service_external_detail' ) );
	}
	elsif ( $obj_view eq 'host_external_detail' ) {
	    push( @menus, ( 'host_profile', 'service_profiles', 'services', 'host_externals', 'host_external_detail' ) );
	}
	else {
	    push( @menus, ( 'host_profile', 'service_profiles', 'parents', 'hostgroups', 'escalation_trees', 'services' ) );
	    if ($externals) {
		push @menus, 'host_externals';
	    }
	}
    }
    $colspan = scalar (@menus);
    my $width = 100 / $colspan . '%';
    my $title = 'Manage Host';
    if ($form_service) { $title .= ' Service' }
    my $detail = qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td valign=top align=left>);

    if ( $obj_view =~ /profile|parents|hostgroups|host_detail|service_detail/ ) {
	$detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<form name=form action="$monarch_cgi/$cgi_exe" onsubmit="selIt();" method=post generator=host_top1>);
    }
    else {
	$detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<form name=form action="$monarch_cgi/$cgi_exe" method=post generator=host_top2>);
    }

    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<table width="$boxwidth" cellpadding=0 cellspacing=0 border=0 style="border-collapse: collapse; border-style: solid; border-width: 0;">
<tr>
<td class=data0 colspan=3>
<table width="100%" cellpadding=7 cellspacing=0 align=left border=0>
<tr>
<td class=head colspan=$colspan>$title</td>
</tr>
</table>
</td>
</tr>
<tr>
<td colspan=3>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>);

    my $class      = undef;
    my $bclass     = undef;
    my @lmenus     = @menus;
    my $last_menu  = pop @lmenus;
    my $first_menu = $menus[0];
    foreach my $view (@menus) {
	if ( $obj_view eq $view ) {
	    $class  = 'top_menu_selected';
	    $bclass = 'topbuttonselected';
	    if ( $view eq $last_menu ) {
		$class = 'top_menu_selected_right';
	    }
	    if ( $view eq $first_menu ) {
		$class = 'top_menu_selected_left';
	    }
	}
	else {
	    $class  = 'top_menu_menu';
	    $bclass = 'topbutton';
	    if ( $view eq $last_menu ) {
		$class = 'top_menu_right';
	    }
	}
	my $menu = '';
	my @menu = split( /_/, $view );
	foreach (@menu) { $menu .= "\u$_ " }
	chop $menu;
	$detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<td class="$class" width="$width" align=center>
<input type=submit class=$bclass name=$view value="$menu">
</td>);
    }

    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
</tr>
<tr>
<td class=top_menu_selected_bar colspan=$colspan></td>
</tr>
</table>
</td>
</tr>
<tr>
<td class=data0 colspan=3>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>
<td class=$form_class width="20%">Host name:</td>
<td class=$form_class width="3%">&nbsp;</td>
<td class=$form_class>$name<input type=hidden name=name value="$name"></td>
</tr>
</table>
</td>
</tr>);
    return $detail;
}

sub host_profile_top(@) {
    my $name       = $_[1];
    my $session_id = $_[2];
    my $obj_view   = $_[3];
    my $externals  = $_[4];
    my $objs       = $_[5];
    local $_;

    my %objs   = ();
    my $urlstr = '';
    my $now    = time;
    if ($objs) {
	%objs = %{$objs};
	foreach my $key ( keys %objs ) {
	    if ( $objs{$key} ) { $urlstr .= '&' . $key . '=' . $objs{$key} }
	}
    }
    my $colspan = 9;
    my @menus = ( 'host_detail', 'parents', 'hostgroups', 'escalation_trees' );
    if ($externals) {
	push( @menus, ( 'externals', 'service_profiles', 'assign_hosts', 'assign_hostgroups', 'apply' ) );
	$colspan = 10;
    }
    else {
	push( @menus, ( 'service_profiles', 'assign_hosts', 'assign_hostgroups', 'apply' ) );
    }
    my $width  = 100 / $colspan . '%';
    my $detail = '';
    if ( $obj_view =~ /parents|host|externals|service_profiles/ ) {
	$detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<form name=form action="$monarch_cgi/$cgi_exe" onsubmit="selIt();" method=post generator=host_profile_top1>);
    }
    else {
	$detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<form name=form action="$monarch_cgi/$cgi_exe" method=post generator=host_profile_top2>);
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<table width="100%" cellpadding=0 cellspacing=0 border=0 style="border-collapse: collapse; border-style: solid; border-width: 0;">
<tr>
<td class=data0 colspan=3>
<table width="100%" cellpadding=7 cellspacing=0 align=left border=0>
<tr>
<td class=head colspan=$colspan>Host Profile</td>
</tr>
</table>
</td>
</tr>
<tr>
<td colspan=3>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>);
    my $class      = undef;
    my @lmenus     = @menus;
    my $last_menu  = pop @lmenus;
    my $first_menu = $menus[0];

    foreach my $view (@menus) {
	if ( $obj_view eq $view ) {
	    $class = 'top_menu_selected';
	    if ( $view eq $last_menu ) {
		$class = 'top_menu_selected_right';
	    }
	    if ( $view eq $first_menu ) {
		$class = 'top_menu_selected_left';
	    }
	}
	else {
	    $class = 'top_menu_menu';
	    if ( $view eq $last_menu ) {
		$class = 'top_menu_right';
	    }
	}
	my $menu = $view;
	$menu = undef;
	my @menu = split( /_/, $view );
	foreach (@menu) { $menu .= "\u$_ " }
	my $cname = $name;
	$cname =~ s/\s/+/g;
	chop $menu;
	$detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<td class="$class" width="$width" align=center>
<a class=top href="$monarch_cgi/$cgi_exe?update_main=1&amp;CGISESSID=$session_id&amp;top_menu=profiles&amp;nocache=$now&amp;view=host_profile&amp;obj_view=$view&amp;name=$cname$urlstr">\u$menu</a>
</td>);
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
</tr>
<tr>
<td class=top_menu_selected_bar colspan=$colspan></td>
</tr>);
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
</table>
</td>
</tr>
<tr>
<td class=data0 colspan=$colspan>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>
<td class=$form_class width="20%">Host profile name:</td>
<td class=$form_class width="3%">&nbsp;</td>
<td class=$form_class>$name<input type=hidden name=name value="$name"></td>
</tr>
</table>
</td>
</tr>);

    return $detail;
}

sub apply_select() {
    my $view       = $_[1];
    my $selected   = $_[2];
    my $nagios_ver = $_[3];
    my $externals  = $_[4];
    my $tab        = $_[5];
    my $tabindex   = $tab ? "tabindex=\"$tab\"" : '';
    my %selected   = %{$selected};
    my $detail     = qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=data0>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>
<td class=$form_class align=left colspan=2 style="height: 0.5em"></td>
</tr>);

    unless ( $view =~ /service$|manage_host|direct_profiles/ ) {
	my $hostgroups_select = defined( $selected{'hostgroups_select'} ) ? $selected{'hostgroups_select'} : '';
	my $hosts_select      = defined( $selected{'hosts_select'} )      ? $selected{'hosts_select'}      : '';
	$detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=$form_class align=right width="30%">Hostgroups action:</td>
<td class=$form_class align=left colspan=2>
<input class=$form_class type=checkbox name=hostgroups_select $hostgroups_select $tabindex>&nbsp;Apply to hostgroups.
</td>
</tr>
<tr>
<td class=$form_class align=right width="30%">Hosts action:</td>
<td class=$form_class align=left>
<input class=$form_class type=checkbox name=hosts_select $hosts_select $tabindex>&nbsp;Apply to hosts.
</td>
</tr>
<tr>
<td class=$form_class align=left colspan=2><hr class=row2></td>
</tr>);
    }

    if ( $view =~ /host_profile|manage_host/ ) {
	my $apply_parents        = $selected{'apply_parents'}        || '';
	my $apply_hostgroups     = $selected{'apply_hostgroups'}     || '';
	my $apply_escalations    = $selected{'apply_escalations'}    || '';
	my $apply_contactgroups  = $selected{'apply_contactgroups'}  || '';
	my $apply_variables      = $selected{'apply_variables'}      || '';
	my $apply_detail         = $selected{'apply_detail'}         || '';
	my $apply_host_externals = $selected{'apply_host_externals'} || '';
	$detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=$form_class align=right width="30%">Host properties action(s):</td>
<td class=$form_class align=left>
<input class=$form_class type=checkbox name=apply_parents $apply_parents $tabindex>&nbsp;Apply parents to hosts.
</td>
</tr>
<tr>
<td class=$form_class align=left width="30%">&nbsp;</td>
<td class=$form_class align=left>
<input class=$form_class type=checkbox name=apply_hostgroups value=replace $apply_hostgroups $tabindex>&nbsp;Apply hostgroups to hosts.
</td>
</tr>
<tr>
<td class=$form_class align=left width="30%">&nbsp;</td>
<td class=$form_class align=left>
<input class=$form_class type=checkbox name=apply_escalations $apply_escalations $tabindex>&nbsp;Apply escalations to hosts.
</td>
</tr>);
	if ( $nagios_ver =~ /^[23]\.x$/ ) {
	    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=$form_class align=left width="30%">&nbsp;</td>
<td class=$form_class align=left>
<input class=$form_class type=checkbox name=apply_contactgroups $apply_contactgroups $tabindex>&nbsp;Apply contact groups to hosts.
</td>
</tr>);
	}
	if ( $nagios_ver eq '3.x' ) {
	    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=$form_class align=left width="30%">&nbsp;</td>
<td class=$form_class align=left>
<input class=$form_class type=checkbox name=apply_variables $apply_variables $tabindex>&nbsp;Apply custom object variables to hosts.
</td>
</tr>);
	}
	$detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=$form_class align=left width="30%">&nbsp;</td>
<td class=$form_class align=left>
<input class=$form_class type=checkbox name=apply_detail $apply_detail $tabindex>&nbsp;Apply detail to hosts.
</td>
</tr>);
	if ($externals) {
	    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=$form_class align=left width="30%">&nbsp;</td>
<td class=$form_class align=left>
<input class=$form_class type=checkbox name=apply_host_externals $apply_host_externals $tabindex>&nbsp;Apply host externals.
</td>
</tr>);
	}
	$detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=$form_class align=left colspan=2><hr class=row2></td>
</tr>);
    }
    if ( $view eq 'service' ) {
	my $apply_check              = $selected{'apply_check'}              || '';
	my $apply_contact_service    = $selected{'apply_contact_service'}    || '';
	my $apply_variables          = $selected{'apply_variables'}          || '';
	my $apply_extinfo_service    = $selected{'apply_extinfo_service'}    || '';
	my $apply_escalation_service = $selected{'apply_escalation_service'} || '';
	my $apply_dependencies       = $selected{'apply_dependencies'}       || '';
	my $apply_service_externals  = $selected{'apply_service_externals'}  || '';
	if ( defined( $selected{'apply_services'} ) && $selected{'apply_services'} eq 'replace' ) {
	    $selected{'replace'} = 'checked';
	    $selected{'merge'}   = '';
	}
	else {
	    $selected{'merge'}   = 'checked';
	    $selected{'replace'} = '';
	}

	$detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=$form_class align=right width="30%">Service properties action(s):</td>
<td class=$form_class align=left>
<input class=$form_class type=checkbox name=apply_check $apply_check $tabindex>&nbsp;Apply service check.
</td>
</tr>
<tr>
<td class=$form_class align=left width="30%">&nbsp;</td>
<td class=$form_class align=left>
<input class=$form_class type=checkbox name=apply_contact_service $apply_contact_service $tabindex>&nbsp;Apply contact groups.
</td>
</tr>);
	if ( $nagios_ver eq '3.x' ) {
	    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=$form_class align=left width="30%">&nbsp;</td>
<td class=$form_class align=left>
<input class=$form_class type=checkbox name=apply_variables $apply_variables $tabindex>&nbsp;Apply custom object variables.
</td>
</tr>);
	}
	$detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=$form_class align=left width="30%">&nbsp;</td>
<td class=$form_class align=left>
<input class=$form_class type=checkbox name=apply_extinfo_service $apply_extinfo_service $tabindex>&nbsp;Apply service extended info.
</td>
</tr>
<tr>
<td class=$form_class align=left width="30%">&nbsp;</td>
<td class=$form_class align=left>
<input class=$form_class type=checkbox name=apply_escalation_service $apply_escalation_service $tabindex>&nbsp;Apply service escalation.
</td>
</tr>
<tr>
<td class=$form_class align=left width="30%">&nbsp;</td>
<td class=$form_class align=left>
<input class=$form_class type=checkbox name=apply_dependencies $apply_dependencies $tabindex>&nbsp;Apply dependencies.
</td>
</tr>);
	if ($externals) {
	    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=$form_class align=left width="30%">&nbsp;</td>
<td class=$form_class align=left>
<input class=$form_class type=checkbox name=apply_service_externals $apply_service_externals $tabindex>&nbsp;Apply service externals.
</td>
</tr>);
	}
	$detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=$form_class align=left colspan=2><hr class=row2></td>
</tr>
<tr>
<td class=$form_class align=right width="30%">Host services action:</td>
<td class=$form_class align=left>
<input type=radio class=radio name=apply_services value=replace $selected{'replace'} $tabindex>&nbsp;Replace existing host service properties (force inheritance).
</td>
</tr>
<tr>
<td class=$form_class align=left width="30%">&nbsp;</td>
<td class=$form_class align=left>
<input type=radio class=radio name=apply_services value=merge $selected{'merge'} $tabindex>&nbsp;Merge with existing host service properties (preserve overrides).
</td>
</tr>);
    }
    unless ( $view eq 'service' ) {
	if ( defined( $selected{'apply_services'} ) && $selected{'apply_services'} eq 'replace' ) {
	    $selected{'replace'} = 'checked';
	    $selected{'merge'}   = '';
	}
	else {
	    $selected{'merge'}   = 'checked';
	    $selected{'replace'} = '';
	}
	# FIX MINOR:  Should this $extra_text be unconditional here?  Check all places
	# where apply_select() is called that invoke this branch of the logic.
	my $extra_text = ($view =~ /manage_host|direct_profiles/) ? ' service profiles and' : '';
	$detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=$form_class align=right width="30%">Services action:</td>
<td class=$form_class align=left>
<input type=radio class=radio name=apply_services value=replace $selected{'replace'} $tabindex>&nbsp;Replace existing$extra_text services.
</td>
</tr>
<tr>
<td class=$form_class align=left width="30%">&nbsp;</td>
<td class=$form_class align=left>
<input type=radio class=radio name=apply_services value=merge $selected{'merge'} $tabindex>&nbsp;Merge with existing$extra_text services.
</td>
</tr>);
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=$form_class align=left colspan=2 style="height: 0.9em"></td>
</tr>
</table>
</td>
</tr>);
    return $detail;
}

sub service_template_top(@) {
    my $name       = $_[1];
    my $session_id = $_[2];
    my $obj_view   = $_[3];
    my $objs       = $_[4];
    my $selected   = $_[5];
    local $_;

    my $boxwidth = ( $obj_view eq 'service_check' ) ? '100%' : '100%';
    my %objs     = ();
    my $urlstr   = '';
    my $now      = time;
    $selected = '' if not defined $selected;
    if ($objs) {
	%objs = %{$objs};
	foreach my $key ( keys %objs ) {
	    if ( $objs{$key} ) { $urlstr .= '&' . $key . '=' . $objs{$key} }
	}
    }
    my $colspan = 3;
    $urlstr =~ s/ /+/g;
    my @menus = ( 'service_detail', 'service_check' );

    my $width  = 100 / $colspan . '%';
    my $detail = qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td valign=top align=left>
<table width="$boxwidth" cellpadding=0 cellspacing=0 border=0 style="border-collapse: collapse; border-style: solid; border-width: 0;">
<tr>
<td class=data0 colspan=3>
<table width="100%" cellpadding=7 cellspacing=0 align=left border=0>
<tr>
<td class=head>Manage Service Template</td>
</tr>
</table>
</td>
</tr>
<tr>
<td colspan=3>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>);
    my $class      = undef;
    my @lmenus     = @menus;
    my $last_menu  = pop @lmenus;
    my $first_menu = $menus[0];
    foreach my $view (@menus) {
	if ( $obj_view eq $view ) {
	    $class = 'top_menu_selected';
	    if ( $view eq $last_menu ) {
		$class = 'top_menu_selected_right';
	    }
	    if ( $view eq $first_menu ) {
		$class = 'top_menu_selected_left';
	    }
	}
	else {
	    $class = 'top_menu_menu';
	    if ( $view eq $last_menu ) {
		$class = 'top_menu_right';
	    }
	}
	my $menu = $view;
	$menu = undef;
	my @menu = split( /_/, $view );
	foreach (@menu) { $menu .= "\u$_ " }
	chop $menu;
	my $ename = uri_escape($name);
	$detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<td class="$class" width="15%" align=center>
<a class=top href="$monarch_cgi/$cgi_exe?update_main=1&amp;CGISESSID=$session_id&amp;nocache=$now&amp;top_menu=services&amp;selected=$selected&amp;view=service_template&amp;obj=service_templates&amp;obj_view=$view&amp;name=$ename$urlstr">\u$menu</a>
</td>);
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<td class=top_menu_fill>&nbsp;</td>
</tr>
<tr>
<td class=top_menu_selected_bar colspan=3></td>
</tr>
</table>);
    if ( $obj_view =~ /service_detail|service_profiles/ ) {
	$detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<form name=form action="$monarch_cgi/$cgi_exe" onsubmit="selIt();" method=post generator=service_template_top1>);
    }
    else {
	$detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<form name=form action="$monarch_cgi/$cgi_exe" method=post generator=service_template_top2>);
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
</tr>
<tr>
<td class=data0 colspan=$colspan>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>
<td class=$form_class width="20%">Service template name:</td>
<td class=$form_class width="3%">&nbsp;</td>
<td class=$form_class>$name</td>
</tr>
</table>
</td>
</tr>);
    return $detail;
}

sub service_top(@) {
    my $name       = $_[1];
    my $session_id = $_[2];
    my $obj_view   = $_[3];
    my $objs       = $_[4];
    my $externals  = $_[5];
    my $selected   = $_[6];
    my $host_id    = $_[7];
    local $_;

    my $boxwidth = ( $obj_view eq 'service_check' ) ? '100%' : '100%';
    my %objs     = ();
    my $urlstr   = '';
    my $now      = time;
    if ($objs) {
	%objs = %{$objs};
	foreach my $key ( keys %objs ) {
	    if ( $objs{$key} ) { $urlstr .= '&' . $key . '=' . $objs{$key} }
	}
    }
    my $colspan = 5;
    $urlstr =~ s/ /+/g;
    my @menus = ( 'service_detail', 'service_check', 'service_dependencies' );
    unless ($host_id)   { push @menus, 'service_profiles' }
    if     ($externals) { push @menus, 'service_externals'; $colspan = 6; }
    unless ($host_id)   { push @menus, 'apply_hosts' }
    $host_id  = '' if not defined $host_id;
    $selected = '' if not defined $selected;

    my $width  = 100 / $colspan . '%';
    my $detail = qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td valign=top align=left>
<table width="$boxwidth" cellpadding=0 cellspacing=0 border=0 style="border-collapse: collapse; border-style: solid; border-width: 0;">
<tr>
<td class=data0 colspan=3>
<table width="100%" cellpadding=7 cellspacing=0 align=left border=0>
<tr>
<td class=head colspan=$colspan>Manage Service</td>
</tr>
</table>
</td>
</tr>
<tr>
<td colspan=3>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>);
    my $class      = undef;
    my @lmenus     = @menus;
    my $last_menu  = pop @lmenus;
    my $first_menu = $menus[0];
    foreach my $view (@menus) {
	if ( $obj_view eq $view ) {
	    $class = 'top_menu_selected';
	    if ( $view eq $last_menu ) {
		$class = 'top_menu_selected_right';
	    }
	    if ( $view eq $first_menu ) {
		$class = 'top_menu_selected_left';
	    }
	}
	else {
	    $class = 'top_menu_menu';
	    if ( $view eq $last_menu ) {
		$class = 'top_menu_right';
	    }
	}
	my $menu = $view;
	$menu = undef;
	my @menu = split( /_/, $view );
	foreach (@menu) { $menu .= "\u$_ " }
	chop $menu;
	my $ename = $name;
	$ename = uri_escape($ename);
	$detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<td class="$class" width="$width" align=center>
<a class=top href="$monarch_cgi/$cgi_exe?update_main=1&amp;CGISESSID=$session_id&amp;nocache=$now&amp;top_menu=services&amp;selected=$selected&amp;view=service&amp;obj=services&amp;obj_view=$view&amp;name=$ename&amp;host_id=$host_id$urlstr">\u$menu</a>
</td>);
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
</tr>
<tr>
<td class=top_menu_selected_bar colspan=$colspan></td>
</tr>
</table>);
    if ( $obj_view =~ /service_detail|service_profiles/ ) {
	$detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<form name=form action="$monarch_cgi/$cgi_exe" onsubmit="selIt();" method=post generator=service_top1>);
    }
    else {
	$detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<form name=form action="$monarch_cgi/$cgi_exe" method=post generator=service_top2>);
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=data0 colspan=$colspan>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>
<td class=$form_class width="20%">Service name:</td>
<td class=$form_class width="3%">&nbsp;</td>
<td class=$form_class>$name</td>
</tr>
</table>
</td>
</tr>);
    return $detail;
}

sub service_profile_top(@) {
    my $name       = $_[1];
    my $session_id = $_[2];
    my $obj_view   = $_[3];
    my $objs       = $_[4];
    my $selected   = $_[5];
    local $_;

    my %objs   = ();
    my $urlstr = '';
    my $now    = time;
    $selected = '' if not defined $selected;
    if ($objs) {
	%objs = %{$objs};
	foreach my $key ( keys %objs ) {
	    if ( $objs{$key} ) { $urlstr .= '&' . $key . '=' . $objs{$key} }
	}
    }
    my $colspan = 5;
    $urlstr =~ s/ /+/g;
    my @menus  = ( 'services', 'assign_hosts', 'assign_hostgroups', 'host_profiles', 'apply' );
    my $width  = 100 / $colspan . '%';
    my $detail = qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td valign=top align=left>
<table width="100%" cellpadding=0 cellspacing=0 border=0 style="border-collapse: collapse; border-style: solid; border-width: 0;">
<tr>
<td class=data0 colspan=3>
<table width="100%" cellpadding=7 cellspacing=0 align=left border=0>
<tr>
<td class=head colspan=$colspan>Service Profile</td>
</tr>
</table>
</td>
</tr>
<tr>
<td colspan=3>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>);
    my $class      = undef;
    my @lmenus     = @menus;
    my $last_menu  = pop @lmenus;
    my $first_menu = $menus[0];

    foreach my $view (@menus) {
	if ( $obj_view eq $view ) {
	    $class = 'top_menu_selected';
	    if ( $view eq $last_menu ) {
		$class = 'top_menu_selected_right';
	    }
	    if ( $view eq $first_menu ) {
		$class = 'top_menu_selected_left';
	    }
	}
	else {
	    $class = 'top_menu_menu';
	    if ( $view eq $last_menu ) {
		$class = 'top_menu_right';
	    }
	}
	my $menu = $view;
	$menu = undef;
	my @menu = split( /_/, $view );
	foreach (@menu) { $menu .= "\u$_ " }
	my $ename = $name;
	$ename = uri_escape($ename);
	chop $menu;
	$detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<td class="$class" width="$width" align=center>
<a class=top href="$monarch_cgi/$cgi_exe?update_main=1&amp;CGISESSID=$session_id&amp;top_menu=profiles&amp;nocache=$now&amp;selected=$selected&amp;view=service_profile&amp;obj=profile&amp;obj_view=$view&amp;name=$ename$urlstr">\u$menu</a>
</td>);
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
</tr>
<tr>
<td class=top_menu_selected_bar colspan=$colspan></td>
</tr>
</table>);
    if ( $obj_view =~ /services|assign_hosts|assign_hostgroups|host_profiles/ ) {
	$detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<form name=form action="$monarch_cgi/$cgi_exe" onsubmit="selIt();" method=post generator=service_profile_top1>);
    }
    else {
	$detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<form name=form action="$monarch_cgi/$cgi_exe" method=post generator=service_profile_top2>);
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=data0 colspan=$colspan>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>
<td class=$form_class width="20%">Service profile name:</td>
<td class=$form_class width="3%">&nbsp;</td>
<td class=$form_class>$name<input type=hidden name=name value="$name"></td>
</tr>
</table>
</td>
</tr>);
    return $detail;
}

sub group_top(@) {
    my $name     = $_[1];
    my $obj_view = $_[2];
    local $_;

    my $now     = time;
    my $colspan = 4;
    my @menus   = ( 'detail', 'hosts', 'sub_groups', 'macros' );

    my $width  = '25%';
    my $title  = 'Manage Group';
    my $detail = qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td valign=top align=left>
<table width="100%" cellpadding=0 cellspacing=0 border=0 style="border-collapse: collapse; border-style: solid; border-width: 0;">
<tr>
<td class=data0 colspan=3>
<table width="100%" cellpadding=7 cellspacing=0 align=left border=0>
<tr>
<td class=head colspan=$colspan>$title</td>
</tr>
</table>
</td>
</tr>
<tr>
<td colspan=3>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>);
    if ( $obj_view =~ /detail|hosts/ ) {
	$detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<form name=form action="$monarch_cgi/$cgi_exe" onsubmit="selIt();" method=post generator=group_top1>);
    }
    else {
	$detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<form name=form action="$monarch_cgi/$cgi_exe" method=post generator=group_top2>);
    }
    my $class      = undef;
    my $bclass     = undef;
    my @lmenus     = @menus;
    my $last_menu  = pop @lmenus;
    my $first_menu = $menus[0];
    foreach my $view (@menus) {
	if ( $obj_view eq $view ) {
	    $class  = 'top_menu_selected';
	    $bclass = 'topbuttonselected';
	    if ( $view eq $last_menu ) {
		$class = 'top_menu_selected_right';
	    }
	    if ( $view eq $first_menu ) {
		$class = 'top_menu_selected_left';
	    }
	}
	else {
	    $class  = 'top_menu_menu';
	    $bclass = 'topbutton';
	    if ( $view eq $last_menu ) {
		$class = 'top_menu_right';
	    }
	}
	my $menu = $view;
	$menu = undef;
	my @menu = split( /_/, $view );
	foreach (@menu) { $menu .= "\u$_ " }
	chop $menu;
	$detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<td class="$class" width="$width" align=center>
<input type=submit class=$bclass name=$view value="$menu">
</td>);
    }

    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
</tr>
<tr>
<td class=top_menu_selected_bar colspan=$colspan></td>
</tr>
</table>
<tr>
<td class=data0 colspan=$colspan>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>
<td class=$form_class width="20%">Monarch group name:</td>
<td class=$form_class width="3%">&nbsp;</td>
<td class=$form_class>$name<input type=hidden name=name value="$name"></td>
</tr>
</table>
</td>
</tr>);
    return $detail;
}

sub access_top(@) {
    my $groupid    = $_[1];
    my $session_id = $_[2];
    my $obj_view   = $_[3];
    my @menus      = @{ $_[4] };
    local $_;

    my $urlstr = undef;
    my $now    = time;
    my $detail = qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td valign=top align=left>
<table width="100%" cellpadding=0 cellspacing=0 border=0 style="border-collapse: collapse; border-style: solid; border-width: 0;">
<tr>
<td class=data0 colspan=3>
<table width="100%" cellpadding=7 cellspacing=0 align=left border=0>
<tr>
<td class=head>Access Values User Group: $groupid</td>
</tr>
</table>
</td>
</tr>
<tr>
<td colspan=3>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>);
    my $class = undef;

    foreach my $view (@menus) {
	if ( $obj_view eq $view ) {
	    $class = 'top_menu_selected';
	}
	else {
	    $class = 'top_menu_menu';
	}
	my $menu = $view;
	$menu = '';
	my @menu = split( /_/, $view );
	foreach (@menu) { $menu .= "\u$_ " }
	chop $menu;
	$detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<td class="$class" align=center>
<a class=top href="$monarch_cgi/$cgi_exe?update_main=1&amp;CGISESSID=$session_id&amp;top_menu=control&amp;nocache=$now&amp;view=control&amp;obj=user_groups&amp;groupid=$groupid&amp;access_set=$view">\u$menu</a>
</td>);
    }
    my $colspan = scalar (@menus);
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
</tr>
<tr>
<td class=top_menu_selected_bar colspan=$colspan></td>
</tr>
</table>
</td>
</tr>
<form name=form action="$monarch_cgi/$cgi_exe" method=post generator=access_top>);
    return $detail;
}

sub escalation_top() {
    my $name       = $_[1];
    my $session_id = $_[2];
    my $obj_view   = $_[3];
    my $type       = $_[4];
    my $nagios_ver = $_[5];
    local $_;

    my $colspan = 4;
    my @menus   = ('detail');
    if ( $obj_view eq 'assign_contact_groups' ) {
	push @menus, 'assign_contact_groups';
    }
    else {
	push( @menus, ( 'assign_hostgroups', 'assign_hosts' ) );
	if ( $type eq 'service' ) {
	    if ( $nagios_ver =~ /^[23]\.x$/ ) {
		push( @menus, ( 'assign_service_groups', 'assign_services' ) );
		$colspan = 5;
	    }
	    else {
		push @menus, 'assign_services';
		$colspan = 4;
	    }
	}
    }
    my $width  = 100 / $colspan . '%';
    my $detail = qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td valign=top align=left>
<table width="100%" cellpadding=0 cellspacing=0 border=0 style="border-collapse: collapse; border-style: solid; border-width: 0;">
<tr>
<td class=data0 colspan=3>
<table width="100%" cellpadding=7 cellspacing=0 align=left border=0>
<tr>
<td class=head colspan=$colspan>Escalation Tree</td>
</tr>
</table>
</td>
</tr>
<tr>
<td colspan=3>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>);
    my $class      = undef;
    my $bclass     = undef;
    my @lmenus     = @menus;
    my $last_menu  = pop @lmenus;
    my $first_menu = $menus[0];
    my $menu_str   = undef;

    foreach my $view (@menus) {
	if ( $obj_view eq $view ) {
	    $class  = 'top_menu_selected';
	    $bclass = 'topbuttonselected';
	    if ( $view eq $last_menu ) {
		$class = 'top_menu_selected_right';
	    }
	    if ( $view eq $first_menu ) {
		$class = 'top_menu_selected_left';
	    }
	}
	else {
	    $class  = 'top_menu_menu';
	    $bclass = 'topbutton';
	    if ( $view eq $last_menu ) {
		$class = 'top_menu_right';
	    }
	}
	my $menu = $view;
	$menu = undef;
	my @menu = split( /_/, $view );
	foreach (@menu) { $menu .= "\u$_ " }
	chop $menu;
	$menu_str .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<td class="$class" width="$width" align=center>
<input type=submit class=$bclass name=$view value="$menu">
</td>);
    }
    $menu_str .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
</tr>
<tr>
<td class=top_menu_selected_bar colspan=$colspan></td>
</tr>);
    unless ( $obj_view =~ /detail/ ) {
	$detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<form name=form action="$monarch_cgi/$cgi_exe" onsubmit="selIt();" method=post generator=escalation_top1>);
    }
    else {
	$detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<form name=form action="$monarch_cgi/$cgi_exe" method=post generator=escalation_top2>);
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
$menu_str
</tr>
</table>
</td>
</tr>
<tr>
<td class=data0 colspan=$colspan>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>
<td class=$form_class width="20%">\u$type escalation tree:</td>
<td class=$form_class>$name
<input type=hidden name=name value="$name">
<input type=hidden name=name value="$type">
</td>
</tr>
</table>
</td>
</tr>);
    return $detail;
}

sub escalation_tree(@) {
    my $ranks     = $_[1];
    my $templates = $_[2];
    my $obj_view  = $_[3];
    my %ranks     = %{$ranks};
    my %templates = %{$templates};
    my $detail    = qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=data0 colspan=3>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>
<td class=$form_class valign=top width="20%">Escalation detail:</td>
<td class=$form_class width="3%">&nbsp;</td>
<td class=$form_class>
<ol>);
    foreach my $rank ( sort { $a <=> $b } keys %ranks ) {
	$detail .= "\n<li>$templates{$ranks{$rank}}{'name'}\n<ul>";
	if ( $templates{ $ranks{$rank} }{'service_description'} ) {
	    unless ( $obj_view eq 'service_detail'
		|| $obj_view eq 'service_names' )
	    {
		$detail .= "\n<li>service_description: $templates{$ranks{$rank}}{'service_description'}</li>";
	    }
	}
	if ( $templates{ $ranks{$rank} }{'notification_interval'} ) {
	    my $val = $templates{ $ranks{$rank} }{'notification_interval'};
	    $val =~ s/-zero-/0/g;
	    $detail .= "\n<li>notification_interval: $val</li>";
	}
	if ( $templates{ $ranks{$rank} }{'first_notification'} ) {
	    my $val = $templates{ $ranks{$rank} }{'first_notification'};
	    $val =~ s/-zero-/0/g;
	    $detail .= "\n<li>first_notification: $val</li>";
	}
	if ( $templates{ $ranks{$rank} }{'last_notification'} ) {
	    my $val = $templates{ $ranks{$rank} }{'last_notification'};
	    $val =~ s/-zero-/0/g;
	    $detail .= "\n<li>last_notification: $val</li>";
	}
	if ( $templates{ $ranks{$rank} }{'contactgroups'} ) {
	    $detail .= "\n<li>contactgroups: $templates{$ranks{$rank}}{'contactgroups'}</li>";
	}
	$detail .= "</ul></li>";
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
</ol>
</td>
</tr>
</table>
</td>
</tr>);
    return $detail;
}

sub show_list(@) {
    my $ranks     = $_[1];
    my $templates = $_[2];
    my $obj_view  = $_[3];
    my %ranks     = %{$ranks};
    my %templates = %{$templates};
    my $detail    = qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=$form_class valign=top width="20%">Escalation detail:
</td>
<td class=$form_class>
<ol>);
    foreach my $rank ( sort { $a <=> $b } keys %ranks ) {
	$detail .= "\n<li>$templates{$ranks{$rank}}{'name'}\n<ul>";
	if ( $templates{ $ranks{$rank} }{'service_description'} ) {
	    unless ( $obj_view eq 'service_detail' ) {
		$detail .= "\n<li>service_description: $templates{$ranks{$rank}}{'service_description'}</li>";
	    }
	}
	if ( $templates{ $ranks{$rank} }{'notification_interval'} ) {
	    $detail .= "\n<li>notification_interval: $templates{$ranks{$rank}}{'notification_interval'}</li>";
	}
	if ( $templates{ $ranks{$rank} }{'first_notification'} ) {
	    $detail .= "\n<li>first_notification: $templates{$ranks{$rank}}{'first_notification'}</li>";
	}
	if ( $templates{ $ranks{$rank} }{'last_notification'} ) {
	    my $val = $templates{ $ranks{$rank} }{'last_notification'};
	    $val =~ s/-zero-/0/g;
	    $detail .= "\n<li>last_notification: $val</li>";
	}
	if ( $templates{ $ranks{$rank} }{'contactgroups'} ) {
	    $detail .= "\n<li>contactgroups: $templates{$ranks{$rank}}{'contactgroups'}</li>";
	}
	$detail .= "</ul></li>";
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
</ol>
</td>
</tr>);
    return $detail;
}

sub service_instances(@) {
    my %instances     = %{ $_[1] };
    my $externals     = $_[2];
    my $base_ext_args = $_[3];
    my $doc           = $_[4];
    my $tab           = $_[5];
    my $tabindex      = $tab ? "tabindex=\"$tab\"" : '';
    my $detail        = qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=data0>
<table width="100%" cellpadding=7 cellspacing=0 align=left border=0>
<tr>
<td class=wizard_title_heading colspan=6 style="padding: 0.5em 8px;" valign=top>Multiple Instances (optional)</td>
</tr>
<tr>
<td>
<table width="100%" cellspacing=0 align=left border=0>
<tr>
<td class=wizard_body colspan=6>
<table width="100%" cellpadding=3 cellspacing=0 align=left border=0>
<tr>
<td>
$doc
</td>
</tr>
</table>
</td>
</tr>
<tr>
<td class=top_border width="100%" colspan=6>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 border=0>
<tr>
<td colspan=6 class=row2_padded>Service&nbsp;instance&nbsp;name&nbsp;suffix:&nbsp;
<input type=text size=20 name=inst value="" $tabindex>
&nbsp;&nbsp;
or&nbsp;enter&nbsp;a&nbsp;numbered&nbsp;range:&nbsp;&nbsp;<input type=text size=4 name=range_from value="" $tabindex>&nbsp;&nbsp;&ndash;&nbsp;&nbsp;<input type=text size=4 name=range_to value="" $tabindex>
&nbsp;&nbsp;
<input class=submitbutton type=submit name=add_instance value="Add Instance(s)" $tabindex>
</td>
</tr>
</table>
</td>
</tr>);
    if (%instances) {
	my @alph_sorted   = ();
	my @num_sorted    = ();
	my %instance_sort = ();
	foreach my $instance ( keys %instances ) {
	    my $inst = $instance;
	    $inst =~ s/^_//;
	    ## FIX LATER:  What is .rand() for?  Will this mess with our sorting or other aspects?
	    $inst .= rand();
	    if ( $inst =~ /^\d+/ ) {
		push @num_sorted, $inst;
	    }
	    else {
		push @alph_sorted, $inst;
	    }
	    $instance_sort{$inst} = $instances{$instance};
	    $instance_sort{$inst}{'name'} = $instance;
	}
	my $bang1 = $externals ? 'Both command arguments and externals arguments' : 'Command arguments';
	my $bang2 = $externals ? 'or externals, respectively,'                    : '';
	my $bang3 = $externals ? 'In either type of arguments, an'                : 'An';
	$detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<script type="text/javascript" language=JavaScript>
function doCheckAll()
{
  with (document.form) {
    for (var i=0; i < elements.length; i++) {
	if (elements[i].type == 'checkbox' && elements[i].name == 'rem_inst')
	   elements[i].checked = true;
    }
  }
}
function doUnCheckAll()
{
  with (document.form) {
    for (var i=0; i < elements.length; i++) {
	if (elements[i].type == 'checkbox' && elements[i].name == 'rem_inst')
	   elements[i].checked = false;
    }
  }
}
function toggle_active(id) {
    var             status_item = document.getElementsByName(      "status_" + id)[0];
    var             active_item = document.getElementById   (      "active_" + id);
    var           chk_args_item = document.getElementsByName(        "args_" + id)[0];
    var       inh_ext_args_item = document.getElementsByName("inh_ext_args_" + id)[0];
    var inh_ext_args_item_label = document.getElementsByName("inh_ext_args_" + id + "_label")[0];
    var     ext_args_item_label = document.getElementsByName(    "ext_args_" + id + "_label")[0];
    var           ext_args_item = document.getElementsByName(    "ext_args_" + id)[0];

    active_item.innerHTML = status_item.checked ? "Active" : "Inactive";
    chk_args_item.disabled = !status_item.checked;
    chk_args_item.className = status_item.checked ? 'enabled' : 'inactive';
    if (ext_args_item) {
	inh_ext_args_item.disabled = !status_item.checked;
	inh_ext_args_item.className = status_item.checked ? 'enabled' : 'disabled';
	inh_ext_args_item_label.className = inh_ext_args_item_label.className.replace(/(_disabled)?\$/, status_item.checked ? '' : '_disabled');
	ext_args_item_label.className = ext_args_item_label.className.replace(/(_disabled)?\$/, !status_item.checked || inh_ext_args_item.checked ? '_disabled': '');
	ext_args_item.disabled  = !status_item.checked || inh_ext_args_item.checked;
	ext_args_item.className = !status_item.checked ? 'inactive' : inh_ext_args_item.checked ? 'disabled' : 'enabled';
    }
}
</script>
<tr>
<td class=top_border colspan=6 valign=top><p class=marginal>
$bang1 are a series of <tt>!</tt>-separated strings which will be substituted into \$ARG#\$
macro references (that is, <tt>\$ARG1\$</tt>, <tt>\$ARG2\$</tt>, ...) within the command $bang2
associated with this service check.  $bang3 initial <tt>!</tt> character will be silently ignored.
</p><p class=marginal>
Argument values will be automatically stripped of any embedded line breaks before saving.&nbsp;
That is true both for explicit line breaks that you type, and for word-wrap display breaks imposed by the browser.&nbsp;
Spaces may be invisibly present at the ends of lines shown here; <i>such spaces will not be stripped</i>.&nbsp;
You can see them by highlighting the full text (triple-left-click in the box).
</p></td>
</tr>
<tr>
<td class=column_head valign=top width="3%">&nbsp;</td>
<td class=column_head align=left valign=top width="20%">Instance Name Suffix</td>
<td class=column_head align=left valign=top width="13%" colspan=2>&nbsp;Active?</td>
<td class=column_head align=left valign=top width="50%">Arguments</td>
<td class=column_head>&thinsp;</td>
</tr>);

	my $class     = 'data6';
	my $ext_class = 'data7';
	foreach my $instance ( ( sort { $a <=> $b } @num_sorted ), ( sort { lc($a) cmp lc($b) } @alph_sorted ) ) {
	    my $instance_status = $instance_sort{$instance}{'status'};
	    my $instance_id     = $instance_sort{$instance}{'id'};
	    my $args            = $instance_sort{$instance}{'args'} // '';
	    my $arg_rows        = int( ( length($args) + 10 ) / 70 ) + 1;
	    $args = HTML::Entities::encode($args);

	    my $checked       = $instance_status ? 'checked' : '';
	    my $active        = $instance_status ? 'Active'  : 'Inactive';
	    my $args_class    = $instance_status ? 'enabled' : 'inactive';
	    my $args_disabled = $instance_status ? ''        : 'disabled';

	    my $top_padding       = $externals ? 'style="padding-top: 4px;"'    : '';
	    my $extra_top_padding = $externals ? 'style="padding-top: 7px;"'    : '';
	    my $bottom_padding    = $externals ? 'style="padding-bottom: 4px;"' : '';
	    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class="$class" valign=top width="3%" $top_padding>
<input type=checkbox name=rem_inst value="$instance_id" $tabindex>
</td>
<td class="$class" align=left valign=top width="20%" $top_padding>
<input type=text name="instance_$instance_id" value="$instance_sort{$instance}{'name'}" $tabindex>
</td>
<td class="$class" valign=top width="1%" $top_padding>
<input type=checkbox name="status_$instance_id" value="$instance_sort{$instance}{'name'}" onclick="toggle_active('$instance_id');" $checked $tabindex>
</td>
<td class="$class" align=left valign=top width="12%" $extra_top_padding><span id="active_$instance_id">$active</span></td>
<td class="$class" align=left valign=top width="64%" $top_padding>
<textarea class=$args_class cols=70 rows=$arg_rows name="args_$instance_id" id="args_$instance_id" wrap=soft $args_disabled $tabindex>$args</textarea>
</td>
<td class="$class">&thinsp;</td>
</tr>);
	    if ($externals) {
		## FIX MINOR:  Ideally, if $inh_ext_args is true (whether initially or when it becomes true while the page is
		## displayed), the $base_ext_args value would be dynamically altered in each instance externals arguments as the
		## base service externals arguments are changed, whether by a change of inheritance at that level or by typing
		## changes to a non-inherited value.  That's more than we can manage right now, so its implementation is deferred.

		my $inh_ext_args = $instance_sort{$instance}{'inh_ext_args'};
		my $ext_args     = $instance_sort{$instance}{'ext_args'} // ( $inh_ext_args ? $base_ext_args : '' );
		my $ext_arg_rows = int( ( length($ext_args) + 10 ) / 70 ) + 1;
		$inh_ext_args = 0 if !defined($inh_ext_args) || $inh_ext_args eq '' || $inh_ext_args eq '-zero-';
		$ext_args = HTML::Entities::encode($ext_args);

		my $tvalue               = $base_ext_args;
		my $control              = "ext_args_$instance_id";
		my $inherit_name         = "inh_$control";
		my $inh_ext_args_checked = $inh_ext_args == 1 ? 'checked' : '';
		my $ext_args_class       = !$instance_status ? 'inactive' : $inh_ext_args ? 'disabled' : ' enabled ';
		my $inh_label_class      = !$instance_status ? 'data7_disabled' : 'data7';
		my $ext_label_class      = !$instance_status || $inh_ext_args ? 'data7_disabled' : 'data7';
		my $inh_disabled         = !$instance_status ? 'disabled' : '';
		my $ext_disabled         = !$instance_status || $inh_ext_args ? 'disabled' : '';

		my $data_alt = defined($tvalue) ? ( 'data-alt="' . HTML::Entities::encode($tvalue) . '"' ) : "data-alt='\0'";
		my $alt = defined($tvalue) ? ( $tvalue eq '1' ? 'alt="true"' : 'alt="false"' ) : "alt='\0'";
		my $onclick = $control ? qq(onclick="toggle_enabled('$inherit_name','$control','$control\_label');") : '';

		$detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class="$ext_class"></td>
<td class="$ext_class" valign=top>
<table width="100%" cellpadding=0 cellspacing=0 align=left border=0>
<tr>
<td class="$ext_class" valign=top><input class=enabled type=checkbox name=$inherit_name id=$inherit_name value=1 $inh_ext_args_checked $alt $inh_disabled $onclick $tabindex></td>
<td class="$ext_class">&nbsp;</td>
<td class="$inh_label_class" name="$inherit_name\_label" style="padding-top: 2px">Inherit externals args from the base service</td>
<td class="$ext_class">&nbsp;</td>
</tr>
</table>
</td>
<td class="$ext_class" align="right" valign=top colspan="2">
<table width="100%" cellpadding=0 cellspacing=0 align=left border=0>
<tr>
<td class="$ext_label_class" align="right" valign=top style="padding-top: 2px" name="$control\_label" id="$control\_label">Externals arguments:</td>
<td class="$ext_class">&nbsp;&nbsp;</td>
</tr>
</table>
</td>
<td class="$ext_class" valign=top width="1%" $bottom_padding>
<textarea class=$ext_args_class cols=70 rows=$ext_arg_rows name="$control" id="$control" wrap=soft $data_alt $ext_disabled $tabindex>$ext_args</textarea>
</td>
<td class="$ext_class">&thinsp;</td>
</tr>);
	    }
	}
	$detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=top_border colspan=6 style="padding: 4px 8px;">
<input class=submitbutton type=submit name=remove_instance value="Remove Instance(s)" $tabindex>&nbsp;&nbsp;
<input class=submitbutton type=button value="Check All" onclick="doCheckAll();" $tabindex>&nbsp;&nbsp;
<input class=submitbutton type=button value="Uncheck All" onclick="doUnCheckAll();" $tabindex>
</td>
</tr>);
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
</table>
</td>
</tr>
</table>
</td>
</tr>);

    return $detail;
}

sub dependency_list(@) {
    my $name         = $_[1];
    my $obj          = $_[2];
    my $service_id   = $_[3];
    my $session_id   = $_[4];
    my $dependencies = $_[5];
    my $role         = $_[6] ? 'Dependent' : 'Master';
    my $generic      = $_[7];
    my %dependencies = %{$dependencies};
    my $view         = 'manage_host';
    if ( $obj eq 'services' ) { $view = 'service' }
    my $now    = time;
    my $title1 = $generic ? "$role Service" : "$role Service Host";
    my $title2 = $generic ? ''              : "$role Service";

    my $url_base = "$monarch_cgi/$cgi_exe?update_main=1&amp;CGISESSID=$session_id&amp;top_menu=$obj&amp;nocache=$now&amp;view=$view&amp;obj=$obj&amp;name=$name&amp;service_id=$service_id&amp;remove_dependency=1";
    if ($role eq 'Master') {
	if ($generic) {
	    $url_base .= "&amp;obj_view=service_dependencies&amp;generic=1";
	}
	else {
	    $url_base .= "&amp;obj_view=service_dependencies";
	}
    }
    else {
	if ($generic) {
	    $url_base .= "&amp;obj_view=confirm_delete_service&amp;selected=$name&amp;submit=remove_service&amp;generic=1";
	}
	else {
	    $url_base .= "&amp;obj_view=confirm_delete_service&amp;selected=$name&amp;submit=remove_service";
	}
    }
    my $detail = qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=data2>
<table width="100%" cellpadding=7 cellspacing=0 align=left border=0>
<tr>
<td class=data2>
<table class=form width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>
<td class=column_head align=left>Dependency</td>
<td class=column_head align=left>$title1</td>
<td class=column_head align=left>$title2</td>
<td class=column_head align=left>&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;</td>
</tr>);
    my $body = undef;
    $name =~ s/ /+/g;

    my $row = 1;
    foreach my $id ( sort { $a <=> $b } keys %dependencies ) {
	my $class = undef;
	if ( $row == 1 ) {
	    $class = 'row_lt';
	    $row   = 2;
	}
	elsif ( $row == 2 ) {
	    $class = 'row_dk';
	    $row   = 1;
	}
	my $third_field  = $generic ? '' : $dependencies{$id}[2];
	$body .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=$class align=left>$dependencies{$id}[0]</td>
<td class=$class align=left>$dependencies{$id}[1]</td>
<td class=$class align=left>$third_field</td>
<td class=$class align=center><a class=action href="$url_base&amp;dependency_id=$id" tabindex='-1'>&nbsp;&nbsp;remove service dependency assignment&nbsp;&nbsp;</a></td>
</tr>);
    }
    if ( !$body ) {
	$body .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=row_lt align=left colspan=4>no dependencies defined
</td>
</tr>);
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
$body
</table>
</td>
</tr>
</table>
</td>
</tr>);
    return $detail;
}

sub dependency_add(@) {
    my $dep_template  = $_[1];
    my $dep_templates = $_[2];
    my $hosts         = $_[3];
    my $service       = $_[4];
    my $docs          = $_[5];
    my $tab           = $_[6];
    my $tabindex      = $tab ? "tabindex=\"$tab\"" : '';
    my @dep_templates = @{$dep_templates};
    my @hosts         = @{$hosts};
    my %docs          = %{$docs};
    my $detail        = qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=data2>
<table width="100%" cellpadding=0 cellspacing=2 align=left border=0 style="padding: 0 5px 5px;">
<tr>
<td class=row2>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 border=0>
<tr>
<td class=row2_padded width="20%" align=left valign=top>Dependency:</td>
<td class=row2 width="3%" valign=top align=center><a class=orange href="#doc" title="$docs{'dependency'}">&nbsp;?&nbsp;</a></td>
<td class=row2 align=left valign=top>
<select name=dep_template onchange="lowlight();submit()" $tabindex>);

    if ( !$dep_templates[0] ) {
	$detail .= "\n<option value=''>-- no dependency templates to add --</option>";
    }
    $detail .= "\n<option selected value=''></option>";
    foreach my $item (@$dep_templates) {
	if ( defined($dep_template) && $item eq $dep_template ) {
	    $detail .= "\n<option selected value=\"$item\">$item</option>";
	}
	else {
	    $detail .= "\n<option value=\"$item\">$item</option>";
	}
    }
    my $size = ( scalar @hosts ) + 1;
    $size = 20 if $size > 20;
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
</select>&nbsp;&nbsp;
</td>
</tr>
</table>
</td>
</tr>
<tr>
<td class=row2>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 border=0>
<tr>
<td class=row2_padded width="20%" align=left valign=top>Master service host:
</td>
<td class=row2 width="3%" valign=top align=center><a class=orange href="#doc" title="$docs{'master_host'}">&nbsp;?&nbsp;</a>
</td>
<td class=row2 valign=top align=left>
<select name=depend_on_host size=$size $tabindex>);
    if ( !$hosts[0] ) {
	$detail .= "\n<option value=''>-- no dependency host names to add --</option>";
    }
    $detail .= "\n<option selected value=''></option>";
    foreach my $item (@hosts) {
	$detail .= "\n<option value=\"$item\">$item</option>";
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
</select>&nbsp;&nbsp;
</td>
</tr>
</table>
</td>
</tr>
);
    if (defined $service) {
	$detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=row2>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 border=0>
<tr>
<td class=row2_padded width="20%" align=left valign=top>Master service:
</td>
<td class=row2 width="3%" valign=top align=center><a class=orange href="#doc" title="$docs{'master_service'}">&nbsp;?&nbsp;</a>
</td>
<td class=row2 align=left>
$service
</td>
</tr>
</table>
</td>
</tr>
);
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
</table>
</td>
</tr>);
    return $detail;
}

sub display_template(@) {
    my $template = $_[1];
    my $plist    = $_[2];
    my %template = %{$template};
    my @props    = split( /,/, $plist );
    my $detail   = qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=data0>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>
<td class=$form_class valign=top width="20%">Detail:</td>
<td class=$form_class width="3%">&nbsp;</td>
<td class=$form_class align=left>
<table width="100%" cellpadding=2 cellspacing=0 border=0>);
    foreach my $p (@props) {
	if ( $p eq 'name' ) { next }
	$template{$p} =~ s/-zero-/0/g;
	$detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=$form_class width="50%">$p</td>
<td class=$form_class align=left>$template{$p}
</td>
</tr>);
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
</table>
</td>
</tr>
</table>
</td>
</tr>);
    return $detail;
}

sub form_files(@) {
    my $upload_dir  = $_[1];
    my $all         = $_[2];
    my $dirs        = $_[3];
    my $files       = $_[4];
    my $description = $_[5];
    my $tab         = $_[6];
    my $tabindex    = $tab ? "tabindex=\"$tab\"" : '';
    my @dirs        = @{$dirs};
    my @files       = @{$files};
    my $detail      = qq(@{[&$Instrument::show_trace_as_html_comment()]}
<script type="text/javascript" language=JavaScript>
function doCheckAll()
{
  with (document.form) {
    for (var i=0; i < elements.length; i++) {
	if (elements[i].type == 'checkbox' && elements[i].name == 'file')
	   elements[i].checked = true;
    }
  }
}
function doUnCheckAll()
{
  with (document.form) {
    for (var i=0; i < elements.length; i++) {
	if (elements[i].type == 'checkbox' && elements[i].name == 'file')
	   elements[i].checked = false;
    }
  }
}
</script>
<tr>
<td class=data0>
<table width="100%" cellpadding=7 cellspacing=0 align=left border=0>
<tr>
<td>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>);
    unless ( $files[0] ) {
	$detail .= "<tr><td class=row1>There are no eligible files in the $upload_dir directory.</td></tr>";
    }
    else {
	my $row = 1;
	@files = sort @files if not $all;
	foreach my $file ( @files ) {
	    my $class = undef;
	    if ( $row == 1 ) {
		$class = 'row_lt';
		$row   = 2;
	    }
	    elsif ( $row == 2 ) {
		$class = 'row_dk';
		$row   = 1;
	    }
	    my $desc = $description->{$file};
	    $desc = '' if not defined $desc;
	    $desc = HTML::Entities::encode($desc);
	    if ($all) {
		my $dir = shift @dirs;
		$detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=$class><input type=hidden name=file value="$dir/$file">$dir</td>);
	    }
	    else {
		$detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=$class width="3%" align=right><input type=checkbox name=file value="$file" $tabindex></td>);
	    }
	    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<td class=$class>$file</td>
<td class=$class align=left>$desc</td>
</tr>);
	}
	if (not $all) {
	    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=top_border colspan=3>
<input class=submitbutton type=button value="Check All" onclick="doCheckAll();" $tabindex>&nbsp;&nbsp;
<input class=submitbutton type=button value="Uncheck All" onclick="doUnCheckAll();" $tabindex>
</td>
</tr>);
	}
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
</table>
</td>
</tr>
</table>
</td>
</tr>);

    return $detail;
}

sub form_groups(@) {
    my $groups   = $_[1];
    my $tab      = $_[2];
    my $tabindex = $tab ? "tabindex=\"$tab\"" : '';
    my %groups   = %{$groups};
    my $detail   = qq(@{[&$Instrument::show_trace_as_html_comment()]}
<script type="text/javascript" language=JavaScript>
function doCheckAll()
{
  with (document.form) {
    for (var i=0; i < elements.length; i++) {
	if (elements[i].type == 'checkbox' && elements[i].name == 'group')
	   elements[i].checked = true;
    }
  }
}
function doUnCheckAll()
{
  with (document.form) {
    for (var i=0; i < elements.length; i++) {
	if (elements[i].type == 'checkbox' && elements[i].name == 'group')
	   elements[i].checked = false;
    }
  }
}
</script>
<tr>
<td class=data0>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>);
    unless ( scalar keys %groups ) {
	$detail .= "&nbsp;There are no groups defined.";
    }
    else {
	foreach my $group ( sort keys %groups ) {
	    my $description = defined( $groups{$group} ) ? $groups{$group} : '';
	    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=$form_class width="4%" align=right><input type=checkbox name=group value="$group" $tabindex></td>
<td class=$form_class width="1%" style="white-space: nowrap;">$group</td>
<td class=$form_class width="1%">&nbsp;</td>
<td class=$form_class>$description</td>
</tr>);
	}
	$detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=top_border colspan=4>
<input class=submitbutton type=button value="Check All" onclick="doCheckAll();" $tabindex>&nbsp;&nbsp;
<input class=submitbutton type=button value="Uncheck All" onclick="doUnCheckAll();" $tabindex>
</td>
</tr>);
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
</table>
</td>
</tr>);

    return $detail;
}

sub service_group(@) {
    my $session_id         = $_[1];
    my $view               = $_[2];
    my $name               = $_[3];
    my $host_services      = $_[4];
    my $host               = $_[5];
    my $host_nonmembers    = $_[6];
    my $hosts              = $_[7];
    my $service            = $_[8];
    my $service_nonmembers = $_[9];
    my $services           = $_[10];
    my $tab                = $_[11];
    local $_;

    my $tabindex           = $tab ? "tabindex=\"$tab\"" : '';
    my %host_services      = %{$host_services};
    my @hosts              = @{$hosts};
    my @host_nonmembers    = @{$host_nonmembers};
    my @services           = @{$services};
    my @service_nonmembers = @{$service_nonmembers};
    my $now                = time;
    $name =~ s/\s/+/g;
    my $hostn = defined($host) ? $host : '';
    $hostn =~ s/\s/+/g;
    my $servicen = defined($service) ? $service : '';
    $servicen =~ s/\s/+/g;
    my $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=data0>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>
<td class=$form_class width="40%" colspan=2 align=left>
<table class=form cellspacing=0 cellpadding=3 width="100%" align=left border=0>
<tr>
<td class=column_head>Host</td>
<td class=column_head>Service</td>
<td class=column_head colspan=2>&nbsp;</td>
</tr>);

    unless (%host_services) {
	$detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=row_lt valign=top>
&nbsp;
</td>
<td class=row_lt valign=top>
&nbsp;
</td>
<td class=row_lt align=center valign=top>
&nbsp;
</td>
</tr>);
    }
    my $row = 1;
    foreach my $host ( sort keys %host_services ) {
	my $hname = $host;
	$hname =~ s/\s/+/g;
	foreach my $service ( @{ $host_services{$host} } ) {
	    my $class = undef;
	    if ( $row == 1 ) {
		$class = 'row_lt';
		$row   = 2;
	    }
	    elsif ( $row == 2 ) {
		$class = 'row_dk';
		$row   = 1;
	    }
	    my $sname = $service;
	    $sname =~ s/\s/+/g;
	    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=$class valign=top>
$host
</td>
<td class=$class valign=top>
$service
</td>
<td class=$class align=center valign=top>
<a class=action href="$monarch_cgi/$cgi_exe?update_main=1&amp;CGISESSID=$session_id&amp;top_menu=services&amp;nocache=$now&amp;view=$view&amp;obj=servicegroups&amp;name=$name&amp;host=$hostn&amp;service=$servicen&amp;del_host=$hname&amp;del_service=$sname&amp;remove_service=1" tabindex='-1'>&nbsp;&nbsp;remove service assignment&nbsp;&nbsp;</a>
</td>
</tr>);
	}
    }

    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
</table>
</td>
</tr>
</table>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>
<td class=$form_class>
<table width="100%" cellpadding=3 cellspacing=0 border=0>
<tr>
<td class=row2 align=left valign=top>Host:</td>
<td class=row2 align=left valign=top>Service(s):</td>
<td class=row2 align=left width="20%" rowspan=2 valign=middle><input class=submitbutton type=submit name=add_services value="Add Service(s)" $tabindex></td>
</tr>
<tr>
<td class=row2 align=left width="40%" valign=top>
<select name=host onchange="lowlight();submit()" $tabindex>);
    unless (@hosts) {
	$detail .= "\n<option selected value=''></option>";
	$detail .= "\n<option value=''>-- no hosts --</option>";
    }
    else {
	if ($host) {
	    $detail .= "\n<option value=''></option>";
	}
	else {
	    $detail .= "\n<option selected value=''></option>";
	}
	foreach my $h (@hosts) {
	    if ( defined($host) && $host eq $h ) {
		$detail .= "\n<option selected value=\"$host\">$host</option>";
	    }
	    else {
		$detail .= "\n<option value=\"$h\">$h</option>";
	    }
	}
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
</select>
</td>
<td class=row2 width="40%" valign=top align=left>
<select name=services size=10 multiple $tabindex>);
    my $options = undef;
    $detail .= "\n<option selected value=''></option>";
    foreach my $nmem (@host_nonmembers) {
	my $got_service = 0;
	if ( defined( $host_services{$host} ) ) {
	    foreach ( @{ $host_services{$host} } ) {
		if ( $_ eq $nmem ) {
		    $got_service = 1;
		    last;
		}
	    }
	}
	unless ($got_service) {
	    $options .= "\n<option value=\"$nmem\">$nmem</option>";
	}
    }
    unless ($options) { $options = "\n<option value=''>-- no services --</option>" }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
$options
</select>
</td>
</tr>
</table>
</td>
</tr>
<tr>
<td class=$form_class>
<table width="100%" cellpadding=3 cellspacing=0 border=0>
<tr>
<td class=row2 align=left valign=top>Service:</td>
<td class=row2 align=left valign=top>Host(s):</td>
<td class=row2 align=left width="20%" rowspan=2 valign=middle><input class=submitbutton type=submit name=add_hosts value="Add Host(s)" $tabindex></td>
</tr>
<tr>
<td class=row2 align=left width="40%" valign=top>
<select name=service onchange="lowlight();submit()" $tabindex>);
    unless (@services) {
	$detail .= "\n<option selected value=''></option>";
	$detail .= "\n<option value=''>-- no hosts --</option>";
    }
    else {
	if ($host) {
	    $detail .= "\n<option value=''></option>";
	}
	else {
	    $detail .= "\n<option selected value=''></option>";
	}
	foreach my $s (@services) {
	    if ( defined($service) && $service eq $s ) {
		$detail .= "\n<option selected value=\"$service\">$service</option>";
	    }
	    else {
		$detail .= "\n<option value=\"$s\">$s</option>";
	    }
	}
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
</select>
</td>
<td class=row2 width="40%" valign=top align=left>
<select name=hosts size=10 multiple $tabindex>);
    $options = undef;
    $detail .= "\n<option selected value=''></option>";
    foreach my $nmem (@service_nonmembers) {
	my $got_host = 0;
	if ( defined( $host_services{$nmem} ) ) {
	    foreach ( @{ $host_services{$nmem} } ) {
		if ( $_ eq $service ) {
		    $got_host = 1;
		    last;
		}
	    }
	}
	unless ($got_host) {
	    $options .= "\n<option value=\"$nmem\">$nmem</option>";
	}
    }
    if ( !$options ) { $options = "\n<option value=''>-- no hosts --</option>" }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
$options
</select>
</td>
</tr>
</table>
</td>
</tr>
</table>
</td>
</tr>);
    return $detail;
}

sub resource_select() {
    my $res       = $_[1];
    my $res_doc   = $_[2];
    my $selected  = $_[3];
    my $view      = $_[4];
    my $tab       = $_[5];
    my $tabindex  = $tab ? "tabindex=\"$tab\"" : '';
    my %resources = %{$res};
    my %res_doc   = %{$res_doc};
    my %selected  = %{$selected};
    my $user      = $selected{'name'};
    $user =~ s/user// if defined $user;
    my $detail  = undef;
    use HTML::Entities;

    if ( ( $view eq 'control' || $view eq 'groups' ) && $selected{'name'} ) {
	my $userval = defined( $selected{'value'} )                ? HTML::Entities::encode($selected{'value'})                : '';
	my $comment = defined( $resources{"resource_label$user"} ) ? HTML::Entities::encode($resources{"resource_label$user"}) : '';
	$detail = qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=data0>
<table cellpadding=0 cellspacing=0 align=left border=0>
<tr>
<td>
<table cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>
<td class=$form_class align=left colspan=2 width="13%"><input type=hidden name=resource value="$selected{'name'}">\U$selected{'name'}\E&nbsp;value:</td>
<td class=$form_class align=left width="70%"><input type=text size=60 name=resource_value value="$userval" $tabindex></td>
</tr>
<tr>
<td class=$form_class align=left colspan=2 width="13%">Description:</td>
<td class=$form_class align=left width="70%"><input type=text size=60 name=comment value="$comment" $tabindex></td>
</tr>
</table>
</td>
<td class=$form_class align=left>&nbsp;&nbsp;</td>
<td class=$form_class align=left><input class=submitbutton type=submit name=update_resource value="Update" $tabindex></td>
</tr>
</table>
</td>
</tr>);
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=data0>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>
<td class=wizard_title_heading style="padding: 0.5em 10px;" align=left colspan=5>Select resource macro to edit</td>
</tr>
<tr>
<td class=row_dk_selected align=left></td>
<td class=row_dk_selected align=left>Macro</td>
<td class=row_dk_selected align=left>Value</td>
<td class=row_dk_selected align=left colspan=2 >Description</td>
</tr>);
    my $class = 'row_dk';
    for ( my $i = 1 ; $i < 33 ; $i++ ) {
	my $value = $resources{"user$i"};
	my $description = $res_doc{"resource_label$i"} || $resources{"resource_label$i"};
	my $password = 0;
	if ( $view eq 'commands' && defined($description) && $description =~ /password/i ) {
	    $password = 1;
	    $value = '************';
	}
	if ( $class =~ /^row_lt/ ) {
	    $class = ( defined( $selected{'name'} ) && $selected{'name'} eq "user$i" ) ? 'row_dk_selected' : 'row_dk';
	}
	elsif ( $class =~ /^row_dk/ ) {
	    $class = ( defined( $selected{'name'} ) && $selected{'name'} eq "user$i" ) ? 'row_lt_selected' : 'row_lt';
	}
	my $checked = ( defined( $selected{'name'} ) && $selected{'name'} eq "user$i" ) ? 'checked' : '';
	my $userval = defined($value)       ? HTML::Entities::encode($value)       : '';
	my $comment = defined($description) ? HTML::Entities::encode($description) : '';
	$detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=$class align=left width="2%" valign=top>
<input class=$form_class type=radio name=resource_macro value=user$i $checked onclick="lowlight();submit()" $tabindex></td>
<td class=$class align=left width="7%" valign=top>USER$i&nbsp;&nbsp;</td>
<td class=$class align=left valign=top>$userval</td>
<td class=$class align=left valign=top>$comment</td>
</tr>);
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
</table>
</td>
</tr>);
    return $detail;
}

sub table_script_links(@) {
    my $session_id = $_[1];
    my $type       = $_[2];
    my $script     = $_[3];
    my %script     = %{$script};
    my $now        = time;
    my $detail     = qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td valign=top>
<table width="100%" cellpadding=3 cellspacing=0 border=0>
<tr>
<td>\u$type Scripts</td>
</tr>);
    foreach my $name ( sort keys %script ) {
	unless ( $name =~ /HASH/ ) {
	    my $url = undef;
	    if ( $script{$name} =~ /Error/ ) {
		$url = qq(@{[&$Instrument::show_trace_as_html_comment()]}<h2>$name - $script{$name}</h2>);
	    }
	    else {
		$url =
qq(@{[&$Instrument::show_trace_as_html_comment()]}<a class=action href="$monarch_cgi/$cgi_exe?update_main=1&amp;CGISESSID=$session_id&amp;top_menu=control&amp;nocache=$now&amp;view=control&amp;obj=run_external_scripts&amp;ext_info=$name&amp;type=$type">$name $script{$name}&nbsp;<img src="$monarch_images/arrow.gif" border=0></a>);
	    }
	    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}\n<tr>\n<td>$url\n</td>\n</tr>);
	}
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
</table>
</td>
</tr>);
    return $detail;
}

sub radio_options(@) {
    my $title    = $_[1];
    my $name     = $_[2];
    my $value    = $_[3];
    my $doc      = $_[4];
    my $tab      = $_[5];
    my $indent   = $_[6];
    my $tabindex = $tab ? "tabindex=\"$tab\"" : '';
    my $other    = 'Use an interleave factor of:';
    my $units    = '';
    my %selected = (
	s     => '',
	d     => '',
	n     => '',
	other => ''
    );
    my $text_val = '';
    if ( $value eq 's' ) {
	$selected{'s'} = 'checked';
    }
    elsif ( $value eq 'd' ) {
	$selected{'d'} = 'checked';
    }
    elsif ( $value eq 'n' ) {
	$selected{'n'} = 'checked';
    }
    else {
	$selected{'other'} = 'checked';
	$text_val = $value;
    }
    $title =~ s/_/ /g;
    my $detail = qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=data0>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>);
    if ($indent) {
	$detail .= "\n<td class=$form_class width='$indent_width' valign=top></td>";
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<td class=$form_class width="20%" valign=top>\u$title</td>);
    if ($doc) {
	$detail .=
	  "\n<td class=$form_class width='3%' valign=top align=center>\n<a class=orange href='#doc' title=\"$doc\" tabindex='-1'>&nbsp;?&nbsp;</a></td>";
    }
    else {
	$detail .= "\n<td class=$form_class width='3%' align=center>\n&nbsp;</td>";
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<td class=$form_class>
<table width="100%" cellpadding=3 cellspacing=0 border=0>);
    if ( $name =~ /inter_check_delay_method|service_inter_check_delay_method|host_inter_check_delay_method/ ) {
	$other = 'Use an inter-check delay of';
	$units = 'seconds.';
	$detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=$form_class width="4%"> <input type=radio class=radio name=radio_option_$name value=n $selected{'n'} $tabindex> </td>
<td class=$form_class> None </td>
</tr>
<tr>
<td class=$form_class width="4%"> <input type=radio class=radio name=radio_option_$name value=d $selected{'d'} $tabindex> </td>
<td class=$form_class> Dumb </td>
</tr>);
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=$form_class width="4%"> <input type=radio class=radio name=radio_option_$name value=s $selected{'s'} $tabindex> </td>
<td class=$form_class> Smart </td>
</tr>
<tr>
<td class=$form_class width="4%"> <input type=radio class=radio name=radio_option_$name value=other $selected{'other'} $tabindex> </td>
<td class=$form_class style="white-space:nowrap; width:auto" align=left>
$other <input type=text size=5 name=other_$name value="$text_val" $tabindex> $units
</td>
</tr>
</table>
</td>
</tr>
</table>
</td>
</tr>);
    return $detail;
}

sub log_rotation(@) {
    my $title    = $_[1];
    my $name     = $_[2];
    my $value    = $_[3];
    my $doc      = $_[4];
    my %selected = ();
    if ( $value eq 'n' ) {
	$selected{'n'} = 'checked';
    }
    elsif ( $value eq 'h' ) {
	$selected{'h'} = 'checked';
    }
    elsif ( $value eq 'd' ) {
	$selected{'d'} = 'checked';
    }
    elsif ( $value eq 'w' ) {
	$selected{'w'} = 'checked';
    }
    elsif ( $value eq 'm' ) {
	$selected{'m'} = 'checked';
    }
    $title =~ s/_/ /g;
    my $detail = qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=data0>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>
<td class=$form_class width="20%" valign=top>\u$title</td>);
    if ($doc) {
	$detail .=
	  "\n<td class=$form_class width='3%' valign=top align=center>\n<a class=orange href='#doc' title=\"$doc\" tabindex='-1'>&nbsp;?&nbsp;</a></td>";
    }
    else {
	$detail .= "\n<td class=$form_class width='3%' align=center>\n&nbsp;</td>";
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<td class=$form_class>
<table width="100%" cellpadding=3 cellspacing=0 border=0>
<tr>
<td class=$form_class width="5%">
<input type=radio class=radio name=log_rotation_method value=n $selected{'n'}>
</td>
<td class=$form_class>
None
</td>
</tr>
<tr>
<td class=$form_class width="5%">
<input type=radio class=radio name=log_rotation_method value=h $selected{'h'}>
</td>
<td class=$form_class>
Hourly
</td>
</tr>
<tr>
<td class=$form_class width="5%">
<input type=radio class=radio name=log_rotation_method value=d $selected{'d'}>
</td>
<td class=$form_class>
Daily
</td>
</tr>
<tr>
<td class=$form_class width="5%">
<input type=radio class=radio name=log_rotation_method value=w $selected{'w'}>
</td>
<td class=$form_class>
Weekly
</td>
</tr>
<tr>
<td class=$form_class width="5%">
<input type=radio class=radio name=log_rotation_method value=m $selected{'m'}>
</td>
<td class=$form_class>
Monthly
</td>
</tr>
</table>
</td>
</tr>
</table>
</td>
</tr>);
    return $detail;
}

sub date_format(@) {
    my $value    = $_[1];
    my $doc      = $_[2];
    my $tab      = $_[3];
    my $indent   = $_[4];
    my $tabindex = $tab ? "tabindex=\"$tab\"" : '';
    my %selected = (
	'us'             => '',
	'euro'           => '',
	'iso8601'        => '',
	'strict-iso8601' => ''
    );
    if ( $value eq 'us' ) {
	$selected{'us'} = 'checked';
    }
    elsif ( $value eq 'euro' ) {
	$selected{'euro'} = 'checked';
    }
    elsif ( $value eq 'iso8601' ) {
	$selected{'iso8601'} = 'checked';
    }
    elsif ( $value eq 'strict-iso8601' ) {
	$selected{'strict-iso8601'} = 'checked';
    }

    my $detail = qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=data0>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>);
    if ($indent) {
	$detail .= "\n<td class=$form_class width='$indent_width' valign=top></td>";
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<td class=$form_class width="20%" valign=top>Date format:</td>);
    if ($doc) {
	$detail .=
	  "\n<td class=$form_class width='3%' valign=top align=center>\n<a class=orange href='#doc' title=\"$doc\" tabindex='-1'>&nbsp;?&nbsp;</a></td>";
    }
    else {
	$detail .= "\n<td class=$form_class width='3%' align=center>\n&nbsp;</td>";
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<td class=$form_class>
<table cellpadding=3 cellspacing=0 border=0>
<tr>
<td class=$form_class><input type=radio class=radio name=date_format value=us $selected{'us'} $tabindex></td>
<td class=$form_class>USA</td>
<td class=$form_class>(MM-DD-YYYY HH:MM:SS)</td>
</tr>
<tr>
<td class=$form_class><input type=radio class=radio name=date_format value=euro $selected{'euro'} $tabindex></td>
<td class=$form_class>International</td>
<td class=$form_class>(DD-MM-YYYY HH:MM:SS)</td>
</tr>
<tr>
<td class=$form_class><input type=radio class=radio name=date_format value=iso8601 $selected{'iso8601'} $tabindex></td>
<td class=$form_class>ISO-8601</td>
<td class=$form_class>(YYYY-MM-DD HH:MM:SS)</td>
</tr>
<tr>
<td class=$form_class><input type=radio class=radio name=date_format value=strict-iso8601 $selected{'strict-iso8601'} $tabindex></td>
<td class=$form_class>strict-ISO-8601</td>
<td class=$form_class>(YYYY-MM-DDTHH:MM:SS)</td>
</tr>
</table>
</td>
</tr>
</table>
</td>
</tr>);
    return $detail;
}

sub debug_verbosity(@) {
    my $value    = $_[1];
    my $doc      = $_[2];
    my $tab      = $_[3];
    my $indent   = $_[4];
    my $tabindex = $tab ? "tabindex=\"$tab\"" : '';
    my %selected = ( '0' => '', '1' => '', '2' => '' );
    if ( $value eq '0' ) {
	$selected{'0'} = 'checked';
    }
    elsif ( $value eq '1' ) {
	$selected{'1'} = 'checked';
    }
    elsif ( $value eq '2' ) {
	$selected{'2'} = 'checked';
    }

    my $detail = qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=data0>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>);
    if ($indent) {
	$detail .= "\n<td class=$form_class width='$indent_width' valign=top></td>";
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<td class=$form_class width="20%" valign=top>Debug verbosity:</td>);
    if ($doc) {
	$detail .=
	  "\n<td class=$form_class width='3%' valign=top align=center>\n<a class=orange href='#doc' title=\"$doc\" tabindex='-1'>&nbsp;?&nbsp;</a></td>";
    }
    else {
	$detail .= "\n<td class=$form_class width='3%' align=center>\n&nbsp;</td>";
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<td class=$form_class>
<table cellpadding=3 cellspacing=0 border=0>
<tr>
<td class=$form_class><input type=radio class=radio name=debug_verbosity value='0' $selected{'0'} $tabindex></td>
<td class=$form_class>Basic information</td>
</tr>
<tr>
<td class=$form_class><input type=radio class=radio name=debug_verbosity value='1' $selected{'1'} $tabindex></td>
<td class=$form_class>More detailed information</td>
</tr>
<tr>
<td class=$form_class><input type=radio class=radio name=debug_verbosity value='2' $selected{'2'} $tabindex></td>
<td class=$form_class>Highly detailed information</td>
</tr>
</table>
</td>
</tr>
</table>
</td>
</tr>);
    return $detail;
}

sub mass_delete(@) {
    my $session_id = $_[1];
    my %hosts      = %{ $_[2] };
    my $detail     = qq(@{[&$Instrument::show_trace_as_html_comment()]}
<script type="text/javascript" language=JavaScript>
function doCheckAll()
{
  with (document.form) {
    for (var i=0; i < elements.length; i++) {
	if (elements[i].type == 'checkbox' && elements[i].name == 'delete_host')
	   elements[i].checked = true;
    }
  }
}
function doUnCheckAll()
{
  with (document.form) {
    for (var i=0; i < elements.length; i++) {
	if (elements[i].type == 'checkbox' && elements[i].name == 'delete_host')
	   elements[i].checked = false;
    }
  }
}
</script>
<tr>
<td class=data0>
<div class="scroll" style="height: 400px;">
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>);
    my $now      = time;
    my $row      = 1;
    my $sort_num = $hosts{'sort_num'};
    delete $hosts{'sort_num'};
    foreach my $host ( sort keys %hosts ) {
	my $class = undef;
	if ( $row == 1 ) {
	    $class = 'row_lt';
	    $row   = 2;
	}
	elsif ( $row == 2 ) {
	    $class = 'row_dk';
	    $row   = 1;
	}
	my $name = uri_escape($host);
	if ($sort_num) {
	    $name = uri_escape( $hosts{$host} );
	}
	else {
	    $hosts{$host} = '&nbsp;';
	}
	$detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class="$class">
<input type=checkbox name=delete_host value=$name>&nbsp;

<!--
<img src="$monarch_images/server.gif" border=0>
-->
$host
<!--
FIX LATER:  possible alternative presentation
<a class=action href="$monarch_cgi/$cgi_exe?update_main=1&amp;CGISESSID=$session_id&amp;nocache=$now&amp;top_menu=hosts&amp;view=manage_host&amp;obj=hosts&amp;name=$name">&nbsp;$host&nbsp;</a>
-->

</td>
<td class="$class">
$hosts{$host} &nbsp;
</td>
</tr>);
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
</table>
</div>
</td>
</tr>);
    return $detail;
}

sub search_results(@) {
    my $objects    = $_[1];
    my $session_id = $_[2];
    my $type       = $_[3];
    my $num_more   = $_[4];
    use URI::Escape;
    my $now     = time;
    my %objects = %{$objects};
    # NOTE:  The blank line here before <table> is vital, as JBoss needs it to separate
    # the (empty) set of header lines from the result contents, so it does not interpret
    # some content as headers, swallow it, and report an error (bad header lines).
    my $detail  = qq(@{[&$Instrument::show_trace_as_html_comment()]}

<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>);

    if (%objects) {
	my @objects = ();
	if ( $objects{'sort_num'} ) {
	    delete $objects{'sort_num'};
	    @objects = sort { $objects{$a} cmp $objects{$b} } keys %objects;
	}
	else {
	    # We use uc, not lc, here to match MySQL collation vs. punctuation.
	    @objects = sort { uc($a) cmp uc($b) } keys %objects;
	}
	my $row = 1;
	foreach my $object (@objects) {
	    my $class = undef;
	    if ( $row == 1 ) {
		$class = 'row_lt';
		$row   = 2;
	    }
	    elsif ( $row == 2 ) {
		$class = 'row_dk';
		$row   = 1;
	    }
	    my $name = $object;
	    $name =~ s/\s/+/g;
	    $name = uri_escape($name);

	    if ( $type eq 'service' ) {
		$detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class="$class">
<a class=action href="$monarch_cgi/$cgi_exe?update_main=1&amp;CGISESSID=$session_id&amp;nocache=$now&amp;top_menu=services&amp;view=service&amp;obj=services&amp;obj_view=service_detail&amp;name=$name" title="$object">
<!--<img src="$monarch_images/service-blue.gif" border=0>-->&nbsp;$objects{$object}&nbsp;</a>
</td>
</tr>);
	    }
	    elsif ( $type eq 'command' ) {
		$detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class="$class">
<a class=action href="$monarch_cgi/$cgi_exe?update_main=1&amp;CGISESSID=$session_id&amp;nocache=$now&amp;top_menu=commands&amp;view=commands&amp;obj=commands&amp;task=modify&amp;name=$name" title="$object">
<!--<img src="$monarch_images/command.gif" border=0>-->&nbsp;$objects{$object}&nbsp;</a>
</td>
</tr>);
	    }
	    elsif ( $type eq 'host_external' ) {
		$detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class="$class">
<a class=action href="$monarch_cgi/$cgi_exe?update_main=1&amp;CGISESSID=$session_id&amp;nocache=$now&amp;top_menu=hosts&amp;view=host_externals&amp;obj=host_externals&amp;task=modify&amp;name=$name" title="$object">
<!--<img src="$monarch_images/template.gif" border=0>-->&nbsp;$objects{$object}&nbsp;</a>
</td>
</tr>);
	    }
	    elsif ( $type eq 'service_external' ) {
		$detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class="$class">
<a class=action href="$monarch_cgi/$cgi_exe?update_main=1&amp;CGISESSID=$session_id&amp;nocache=$now&amp;top_menu=services&amp;view=service_externals&amp;obj=service_externals&amp;task=modify&amp;name=$name" title="$object">
<!--<img src="$monarch_images/template.gif" border=0>-->&nbsp;$objects{$object}&nbsp;</a>
</td>
</tr>);
	    }
	    elsif ( $type eq 'ez' ) {
		$detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class="$class">
<a class=action href="$monarch_cgi/monarch_ez.cgi?update_main=1&amp;CGISESSID=$session_id&amp;nocache=$now&amp;top_menu=hosts&amp;view=hosts&amp;obj=hosts&amp;name=$name" title="$object">
<!--<img src="$monarch_images/server.gif" border=0>-->&nbsp;$objects{$object}&nbsp;</a>
</td>
</tr>);
	    }
	    elsif ( $type eq 'delete_hosts' ) {
		$detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class="$class">
<input type=checkbox name=delete_host value=$name>&nbsp;
<!--<img src="$monarch_images/server.gif" border=0>-->&nbsp;$objects{$object}&nbsp;</a>
</td>
</tr>);
	    }
	    else {
		my $ipaddr = '';
		if ($object ne $objects{$object}) {
		    $ipaddr =
qq(&nbsp;<a class=action href="$monarch_cgi/$cgi_exe?update_main=1&amp;CGISESSID=$session_id&amp;nocache=$now&amp;top_menu=hosts&amp;view=manage_host&amp;obj=hosts&amp;name=$name" title="$object">&nbsp;$objects{$object}&nbsp;</a>);
		}
		$detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class="$class">
<a class=action href="$monarch_cgi/$cgi_exe?update_main=1&amp;CGISESSID=$session_id&amp;nocache=$now&amp;top_menu=hosts&amp;view=manage_host&amp;obj=hosts&amp;name=$name" title="$object">
<!--<img src="$monarch_images/server.gif" border=0>-->&nbsp;$object&nbsp;</a>
</td>
<td class="$class">$ipaddr</td>
<td class="$class" width="80%"></td>
</tr>);
	    }
	}
    }
    else {
	$detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=row_lt>
&nbsp;Nothing found
</td>
</tr>);
    }
    if ( $num_more > 0 ) {
	$detail .= "\n<tr><td class=row2 colspan='3'>($num_more more)</td></tr>";
    }
    $detail .= "\n</table>";
    return $detail;
}

sub search(@) {
    my $session_id      = $_[1];
    my $type            = $_[2];
    my $value           = $_[3];
    my $search_function = '';
    my $caption         = "Input any part of a host name or address:";
    if (defined $type) {
	if ( $type eq 'services' ) {
	    $caption = "Input any part of a service name:";
	}
	elsif ( $type eq 'commands' ) {
	    $caption = "Input any part of a command name:";
	}
	elsif ( $type eq 'host_externals' ) {
	    $caption = "Input any part of a host external name:";
	}
	elsif ( $type eq 'service_externals' ) {
	    $caption = "Input any part of a service external name:";
	}
    }
    my $detail = qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=data0>
<table cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>
<td class=$form_class>$caption</td>
<td class=$form_class>
<input type=hidden id=CGISESSID name=CGISESSID value=$session_id>);

    # We impose an imperceptible delay to cut down on excess queries.
    $search_function = 'find_hosts';
    if (defined $type) {
	if ( $type eq 'services' ) {
	    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<input type=hidden id=service name=service value=service>);
	    $search_function = 'find_services';
	}
	elsif ( $type eq 'commands' ) {
	    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<input type=hidden id=command name=command value=command>);
	    $search_function = 'find_commands';
	}
	elsif ( $type eq 'host_externals' ) {
	    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<input type=hidden id=external name=external value=external>
<input type=hidden id=type name=type value=host>);
	    $search_function = 'find_externals';
	}
	elsif ( $type eq 'service_externals' ) {
	    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<input type=hidden id=external name=external value=external>
<input type=hidden id=type name=type value=service>);
	    $search_function = 'find_externals';
	}
	elsif ( $type eq 'ez' ) {
	    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<input type=hidden id=ez name=ez value=ez>);
	    $search_function = 'find_ez_hosts';
	}
    }

    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<input type=text name=input id="val1" size=60 onkeyup="setTimeout ($search_function, 200);">
</td>
</tr>
</table>
</td>
</tr>
<tr>
<td class=data0>
<script type="text/javascript" language=JavaScript>
function SetInputFocus() {
    document.getElementById('val1').focus();
}
SafeAddOnload(SetInputFocus);

var UseEyeCandy = false;
var KillOldResults = false;
function erase_cover() {
    document.getElementById('grayarea').removeChild(document.getElementById('coverGlass'));
}
function show_cover() {
    if (document.getElementById('coverGlass')) return;
    sheet = document.getElementById('grayarea').appendChild(document.createElement('div'));
    sheet.style.top = '-3000px';
    sheet.style.width  = document.getElementById('grayarea').offsetWidth  + 'px';
    sheet.style.height = document.getElementById('grayarea').offsetHeight + 'px';
    sheet.style.left   = document.getElementById('grayarea').offsetLeft   + 'px';
    sheet.style.top    = document.getElementById('grayarea').offsetTop    + 'px';
    sheet.id = 'coverGlass';
    sheet.onclick = function() { this.blur(); erase_cover(); return false; }
}
var LastRequestTime = new Date();
var LastDisplayTime = new Date();
var LastRequest = '';
var LastDisplay = '';
function show_results() {
    var arr = arguments[0].split('|');
    var response = arr[0];
    var request  = arr[1];
    // Do not display obsolete or redundant results.
    if (document.getElementById("val1").value == request) {
	if (UseEyeCandy) {
	    erase_cover();
	}
	document.getElementById('searchdiv').innerHTML = 'Search results:';
	var now = new Date();
	if (request != LastDisplay || (now.getTime() - LastDisplayTime.getTime()) > 2000) {
	    document.getElementById('resultdiv').innerHTML = response;
	    LastDisplayTime = now;
	    LastDisplay = request;
	}
    }
}
// Avoid pointless successive identical requests.
function find_objects(get_objects) {
    var request = document.getElementById("val1").value;
    var now = new Date();
    if (request != LastRequest || (now.getTime() - LastRequestTime.getTime()) > 3000) {
	LastRequestTime = now;
	LastRequest = request;
	document.getElementById('searchdiv').innerHTML = '<font color=#CC0000>Searching ...</font>';
	if (UseEyeCandy) {
	    show_cover();
	} else if (KillOldResults) {
	    document.getElementById('resultdiv').innerHTML = '&nbsp;';
	    LastDisplay = '';
	}
	eval (get_objects);
    }
}
function find_services() {
    find_objects( "get_services( ['service','val1','CGISESSID'], [show_results] )" );
}
function find_commands() {
    find_objects( "get_commands( ['command','val1','CGISESSID'], [show_results] )" );
}
function find_externals() {
    find_objects( "get_externals( ['external','type','val1','CGISESSID'], [show_results] )" );
}
function find_ez_hosts() {
    find_objects( "get_ez( ['ez','val1','CGISESSID'], [show_results] )" );
}
function find_hosts() {
    find_objects( "get_hosts( ['val1','CGISESSID'], [show_results] )" );
}
function find_names() {
    $search_function();
}
</script>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>
<td class=row2>
<div id="searchdiv">
Results will appear below.
</div>
</td>
</tr>
<tr>
<td class=$form_class id="grayarea" style="position: relative;">
<div id="resultdiv">
&nbsp;
</div>
</td>
</tr>
</table>
</td>
</tr>);
    return $detail;
}

sub toggle_delete() {
    my $help_url = $_[1];
    my $detail   = '';
    $detail .= js_utils() if $help_url;
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td>
<table width="100%" cellpadding=0 cellspacing=0 align=left border=0>
<tr>
<td><input class=submitbutton type=submit name=remove_host value="Delete">&nbsp;&nbsp;
<input class=submitbutton type=button value="Check All" onclick="doCheckAll();">&nbsp;&nbsp;
<input class=submitbutton type=button value="Uncheck All" onclick="doUnCheckAll();">&nbsp;&nbsp;
<input type=submit class=submitbutton name=close value="Close">&nbsp;&nbsp;);
    if ($help_url) {
	$detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<input class=submitbutton type=button name=help value="Help" onclick="open_window('$help_url')">);
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
</td>
</tr>
</form>
</table>
</td>
</tr>);
    return $detail;
}

sub wizard_doc(@) {
    my $title       = $_[1];
    my $body        = $_[2];
    my $emphasize   = $_[3];
    my $heading     = $_[4];
    my $body_begin  = '';
    my $body_end    = '';
    if ($emphasize) {
	$title = "<span class=wizard_title_standout>&nbsp;$title&nbsp;</span>" if $title;
	$body_begin  = '<b><i>';
	$body_end    = '</i></b>';
    }
    my $head_class   = $heading ? 'wizard_title_heading' : 'wizard_title';
    my $head_style   = $heading ? ''                     : 'style="padding-bottom: 0;"';
    my $body_padding = $heading ? 3                      : 0;
    my $detail = qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr class=no_border>
<td class=data0 colspan=3>
<table width="100%" cellpadding=7 cellspacing=0 align=left border=0>);
    if ( defined($title) ) {
	$detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=$head_class $head_style>$title</td>
</tr>);
    }

    if ( defined($body) ) {
	$detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=wizard_body>
<table width="100%" cellpadding=$body_padding cellspacing=0 align=left border=0>
<tr>
<td class=wizard_body>$body_begin$body$body_end</td>
</tr>
</table>
</td>
</tr>);
    }

    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
</table>
</td>
</tr>);

    return $detail;
}

sub process_import(@) {
    my $import_option  = $_[1];
    my $escalation     = $_[2];
    my $nagios_etc     = $_[3];
    my $abort          = $_[4];
    my $continue       = $_[5];
    my $precached_file = $_[6];
    my $now            = time;
    $escalation = '' if not defined $escalation;
    my $input_tags = qq(@{[&$Instrument::show_trace_as_html_comment()]}
<input type=hidden id="nocache" name=nocache value=$now>
<input type=hidden id="end" name=end value=end>
<input type=hidden id="process_import" name=process_import value=process_import>
<input type=hidden id="import_option" name=import_option value=$import_option>
<input type=hidden id="escalation" name=escalation value=$escalation>
<input type=hidden id="precached_file" name=precached_file value="$precached_file">
<input type=hidden id="nagios_etc" name=nagios_etc value=$nagios_etc>
<input type=hidden id="process_service_escalations" name=process_service_escalations value=process_service_escalations>
<input type=hidden id="process_host_escalations" name=process_host_escalations value=process_host_escalations>
<input type=hidden id="services" name=services value=services>
<input type=hidden id="hosts" name=hosts value=hosts>
<input type=hidden id="contacts" name=contacts value=contacts>
<input type=hidden id="timeperiods" name=timeperiods value=timeperiods>
<input type=hidden id="commands" name=commands value=commands>
<input type=hidden id="stage" name=stage value=stage>
<input type=hidden id="purge" name=purge value=purge>);
    my @steps = ('end');

    if ( $escalation || $import_option =~ /purge/ ) {
	push( @steps, ( 'process_service_escalations', 'process_host_escalations' ) );
    }
    push( @steps, ( 'services', 'hosts', 'contacts', 'timeperiods', 'commands', 'stage', 'purge' ) );
    my $i         = 0;
    my $array_str = undef;
    foreach my $step (@steps) {
	$array_str .= qq(steps[$i]="$step";);
	$i++;
    }
    my $javascript = qq(@{[&$Instrument::show_trace_as_html_comment()]}
<script type="text/javascript" language=JavaScript>
var got_warning = false;
var got_error = false;
var steps= new Array($i)
$array_str
function check_status() {
	var step = steps.pop()
	if (step==undefined) {
		if (got_error) {
		    document.getElementById("status").innerHTML = "Finished with error(s); see below for detail.";
		    document.getElementById("status").style.color = "#CC0000";
		}
		else if (got_warning) {
		    document.getElementById("status").innerHTML = "Finished with warning(s); see below for detail.";
		    document.getElementById("status").style.color = "#EA840F";
		}
		else {
		    document.getElementById("status").innerHTML = "Finished";
		}
		document.getElementById("status").style.fontWeight = 'bold';
		document.getElementById("continue_abort").value="$continue";
	}
	else {
		var str = '';
		if (step=='process_service_escalations') str = 'Processing service escalations ...';
		if (step=='process_host_escalations') str = 'Processing host escalations ...';
		if (step=='services') str = 'Processing services ...';
		if (step=='hosts') str = 'Processing hosts ...';
		if (step=='contacts') str = 'Processing contacts ...';
		if (step=='timeperiods') str = 'Processing timeperiods ...';
		if (step=='commands') str = 'Processing commands ...';
		if (step=='stage') str = 'Reading files ...';
		if (step=='purge') str = 'Preparing import ...';
		document.getElementById("continue_abort").value="$abort";
		document.getElementById("status").innerHTML = str;
		process_import( ['process_import',step,'nagios_etc','import_option','escalation','precached_file'], [report_status] )
	}
}

function report_status(id) {
	var args = arguments[0].split('|')
	var items = args.length
	for (i=0; i<items; i++) {
		var fields = args[i].split('~~')
		var tbody = document.getElementById("reportTable").getElementsByTagName("TBODY")[0];
		var row = document.createElement("TR")
		var td1 = document.createElement("TD")
		td1.appendChild(document.createTextNode(fields[0]))
		var td2 = document.createElement("TD")
		td2.appendChild (document.createTextNode(fields[1]))
		var td3 = document.createElement("TD")
		td3.appendChild (document.createTextNode(fields[2]))
		if (fields[1] == 'warning') {
			got_warning = true;
			td2.style.color = '#EA840F';
			td3.style.color = '#EA840F';
			td2.style.fontWeight = 'bold';
			td3.style.fontWeight = 'bold';
		}
		if (fields[1] == 'error') {
			got_error = true;
			td2.style.color = '#CC0000';
			td3.style.color = '#CC0000';
			td2.style.fontWeight = 'bold';
			td3.style.fontWeight = 'bold';
		}
		row.appendChild(td1);
		row.appendChild(td2);
		row.appendChild(td3);
		tbody.appendChild(row);
	}
	check_status()
}
</script>
);

    my $detail = qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=data3>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>
<td class=$form_class valign=top width="20%">Status:</td>
<td class=$form_class><div id="status"></div>
</td>
</tr>
</table>
</td>
</tr>
<tr>
<td>
$javascript
$input_tags
<div class="scroll">
<table id="reportTable" width="100%" cellpadding=7 cellspacing=0 align=left border=0>
<tbody>
</tbody>
</table>
</div>
</td>
</tr>
<tr>
<td class=buttons>
<table width="100%" cellpadding=0 cellspacing=0 border=0>
<tr>
<td style=border:0 align=left>
<input class=submitbutton id="continue_abort" type=submit name=continue value=''>
</td>
</tr>
</form>
</table>
</td>
</tr>);
}

sub import_options(@) {
    my $import_option  = $_[1];
    my $precached_file = $_[2];
    my $tab            = $_[3];
    my $tabindex       = $tab ? "tabindex=\"$tab\"" : '';
    my %selected       = (
	'update'                  => '',
	'purge_all'               => '',
	'purge_all_and_import_3x' => '',
	'purge_nice'              => '',
    );
    if ( !$import_option ) {
	$import_option = 'update';
    }
    $selected{$import_option} = 'checked';
    return qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=data0>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>
<td class=wizard_title_heading style="padding: 0.5em 10px;" valign=top>Import Options</td>
</tr>
<tr>
<td style="padding: 0 10px;">
<p class=append>
The import process will read a set of Nagios configuration files,
starting with the nagios.cfg and cgi.cfg files in the /usr/local/groundwork/nagios/etc/ directory.
Before you proceed, you must copy your to-import versions of those two files into that location.
Also, you must ensure that all the cfg_dir, cfg_file, and resource_file directives
in those two files point to the places where your other files to import are located.
Then select one of the options below.
</p>
</td>
</tr>
<tr>
<td class=wizard_body>
<table width="100%" cellpadding=7 cellspacing=0 align=left border=0>
<tr>
<td class=wizard_body width="2%" valign=baseline align=center>
<input class=radio type=radio name=import_option value=update $selected{'update'} $tabindex>
</td>
<td class=wizard_body colspan="2" valign=baseline><i>Update</i> (default): Add and update objects from the file definitions. Note: Escalations are excluded unless you select "Import escalations" below.
</td>
</tr>
<tr>
<td class=wizard_body width="2%" valign=baseline>&nbsp;</td>
<td class=wizard_body width="2%" valign=baseline><input class=checkbox type=checkbox name=purge_escalations $tabindex></td>
<td class=wizard_body valign=baseline><i>Import escalations</i>: Replace escalations from the file definitions. There is no option to update escalations.</td>
</tr>
<tr>
<td class=wizard_body width="2%" valign=baseline align=center>
<input class=radio type=radio name=import_option value=purge_nice $selected{'purge_nice'} $tabindex>
</td>
<td class=wizard_body colspan="2" valign=baseline><i>Purge nice</i>: Clear Nagios service related records, including services, service dependencies, service templates, and escalations; but preserve hosts, commands, time periods, contacts, and profiles (including service profiles). This option will update hosts, commands, time periods, and contacts from the file definitions. Service profiles remain as empty vessels.
</td>
</tr>
<tr>
<td class=wizard_body width="2%" valign=baseline align=center>
<input class=radio type=radio name=import_option value=purge_all $selected{'purge_all'} $tabindex>
</td>
<td class=wizard_body colspan="2" valign=baseline><i>Purge all</i>: Completely clear all Nagios records, including profiles and their associations, from the database. This option will repopulate the database from the file definitions. Since Nagios configuration files do not contain all the relationships stored within a GroundWork configuration, some information may be lost. Some relationships, such as host templates assigned to hosts, will be manufactured on a best-guess basis if they are not already established in the incoming files. In other cases, the data will be adjusted to fit within the supported data model, such as collapsing chains of host template references.</td>
</tr>
<tr>
<td class=wizard_body width="2%" valign=baseline align=center>
<input class=radio type=radio name=import_option value=purge_all_and_import_3x $selected{'purge_all_and_import_3x'} $tabindex>
</td>
<td class=wizard_body colspan="2" valign=baseline><i>Nagios 3.x import</i>: Clears the database of all Nagios records, just as <i>Purge all</i> does, and replaces them with data from the Nagios 3.x configuration files. To use this option, you must have created a Nagios 3.x <i>precached objects file</i> by running <b>nagios -vp /usr/local/groundwork/nagios/etc/nagios.cfg</b> from the command line. The import process also reads the main nagios.cfg file and any files it includes by reference, in order to pull in any templates found in those files. Although the templates will be imported into Monarch, they will not be associated with any objects. You can do this later by adding templates to profiles, then applying the profiles to hosts or other objects. Finally, note that all custom object variables will be capitalized in the precached objects file, and so may not match what is in the Nagios configuration files (merging of names from the different sources may not produce the expected results).</td>
</tr>
<tr>
<td class=wizard_body width="2%">&nbsp;</td>
<td class=wizard_body colspan="2"><i>Precached objects file</i>: <input type=text size=75 name=precached_file value="$precached_file" $tabindex></td>
</tr>
</table>
</td>
</tr>
</table>
</td>
</tr>);
}

sub form_process_hosts(@) {
    my $unsorted_hosts  = $_[1];
    my $host_data       = $_[2];
    my $delimiter       = $_[3];
    my $fields          = $_[4];
    my $exists          = $_[5];
    my $profiles        = $_[6];
    my $default_profile = $_[7];
    my $sort            = $_[8];
    my $ascdesc         = $_[9];
    my @unsorted_hosts  = @{$unsorted_hosts};
    my %host_data       = %{$host_data};
    my %fields          = %{$fields};
    my %exists          = %{$exists};
    my %profiles        = %{$profiles};
    my @hosts           = ();
    my %checked         = ();
    my %sorted          = ();
    my %sort_order      = (
	'exception' => 'asc',
	'exists'    => 'asc',
	'good'      => 'asc',
	'name'      => 'asc',
	'alias'     => 'asc',
	'address'   => 'asc',
	'os'        => 'asc',
	'profile'   => 'asc',
	'other'     => 'asc'
    );

    if ($sort) {
	@{ $sorted{'os'} }        = ();
	@{ $sorted{'address'} }   = ();
	@{ $sorted{'alias'} }     = ();
	@{ $sorted{'profile'} }   = ();
	@{ $sorted{'other'} }     = ();
	@{ $sorted{'exception'} } = ();
	@{ $sorted{'exists'} }    = ();
	@{ $sorted{'good'} }      = ();
	foreach my $host (@unsorted_hosts) {
	    my @values = split( /$delimiter/, $host_data{$host} );
	    if ( $delimiter eq 'tab' ) {
		@values = split( /\t/, $host_data{$host} );
	    }
	    if ( $sort eq 'os' ) {
		unless ( $values[ $fields{'os'} ] ) {
		    $values[ $fields{'os'} ] = "&nbsp;---&nbsp;";
		}
		push @{ $sorted{ $values[ $fields{'os'} ] } }, $values[ $fields{'name'} ];
	    }
	    elsif ( $sort eq 'address' ) {
		push @{ $sorted{ $values[ $fields{'address'} ] } }, $values[ $fields{'name'} ];
	    }
	    elsif ( $sort eq 'alias' ) {
		unless ( $values[ $fields{'alias'} ] ) {
		    $values[ $fields{'alias'} ] = $values[ $fields{'name'} ];
		}
		push @{ $sorted{ $values[ $fields{'alias'} ] } }, $values[ $fields{'name'} ];
	    }
	    elsif ( $sort eq 'profile' ) {
		my $profile = '&nbsp;---&nbsp;';
		if ( $profiles{ $values[ $fields{'profile'} ] } ) {
		    $profile = $values[ $fields{'profile'} ];
		}
		push @{ $sorted{$profile} }, $values[ $fields{'name'} ];
	    }
	    elsif ( $sort eq 'other' ) {
		push @{ $sorted{ $values[ $fields{'other'} ] } }, $values[ $fields{'name'} ];
	    }
	    elsif ($sort eq 'exception'
		|| $sort eq 'exists'
		|| $sort eq 'good' )
	    {
		unless ( $values[ $fields{'alias'} ] ) {
		    $values[ $fields{'alias'} ] = $values[ $fields{'name'} ];
		}
		if (   $values[ $fields{'name'} ]
		    && $values[ $fields{'address'} ] )
		{
		    if ( $exists{ $values[ $fields{'name'} ] } ) {
			push @{ $sorted{'exists'} }, $values[ $fields{'name'} ];
			if ( $sort eq 'exists' ) { $checked{$host} = 'checked' }
		    }
		    else {
			push @{ $sorted{'good'} }, $values[ $fields{'name'} ];
			if ( $sort eq 'good' ) { $checked{$host} = 'checked' }
		    }
		}
		else {
		    push @{ $sorted{'exception'} }, $values[ $fields{'name'} ];
		    if ( $sort eq 'exception' ) { $checked{$host} = 'checked' }
		}
	    }
	}
	if ( $sort eq 'exception' || $sort eq 'exists' || $sort eq 'good' ) {
	    my @order = ();
	    if ( $sort eq 'exception' ) {
		@order = ( 'exception', 'exists', 'good' );
	    }
	    elsif ( $sort eq 'exists' ) {
		@order = ( 'exists', 'good', 'exception' );
	    }
	    else {
		@order = ( 'good', 'exception', 'exists' );
	    }
	    foreach my $key (@order) {
		@{ $sorted{$key} } =
		  sort { lc($a) cmp lc($b) } @{ $sorted{$key} };
		push( @hosts, @{ $sorted{$key} } );
	    }
	    $sort_order{$sort} = 'asc';
	}
	else {
	    if ( $ascdesc eq 'asc' ) {
		foreach my $key ( sort { lc($a) cmp lc($b) } keys %sorted ) {
		    @{ $sorted{$key} } =
		      sort { lc($a) cmp lc($b) } @{ $sorted{$key} };
		    push( @hosts, @{ $sorted{$key} } );
		}
		$sort_order{$sort} = 'desc';
	    }
	    else {
		foreach my $key ( sort { lc($b) cmp lc($a) } keys %sorted ) {
		    @{ $sorted{$key} } =
		      sort { lc($a) cmp lc($b) } @{ $sorted{$key} };
		    push( @hosts, @{ $sorted{$key} } );
		}
		$sort_order{$sort} = 'asc';
	    }
	}
    }
    else {
	if ( $ascdesc eq 'asc' ) {
	    @hosts = sort { lc($a) cmp lc($b) } @unsorted_hosts;
	    $sort_order{'name'} = 'desc';
	}
	else {
	    @hosts = sort { lc($b) cmp lc($a) } @unsorted_hosts;
	    $sort_order{'name'} = 'asc';
	}
    }
    my $detail = qq(@{[&$Instrument::show_trace_as_html_comment()]}
<script type="text/javascript" language=JavaScript>
function doCheckAll()
{
  with (document.form) {
    for (var i=0; i < elements.length; i++) {
	if (elements[i].type == 'checkbox' && elements[i].name == 'host_checked')
	   elements[i].checked = true;
    }
  }
}
function doUnCheckAll()
{
  with (document.form) {
    for (var i=0; i < elements.length; i++) {
	if (elements[i].type == 'checkbox' && elements[i].name == 'host_checked')
	   elements[i].checked = false;
    }
  }
}
</script>
<tr>
<td class=data0>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>
<td class=$form_class width="15%">Sort keys:</td>
<td class=$form_class align=left width="1%">
<div style="width:8px; height:8px; border:1px solid #000099; background-color:#F3B50F;"></div>
</td>
<td class=$form_class align=left width="20%"><input class=row1button type=submit name=sort_exception_$sort_order{'exception'} value="&nbsp;Exception: Missing data, unable to import.&nbsp;&nbsp;">
</td>
<td class=$form_class align=left width="1%">
<div style="width:8px; height:8px; border:1px solid #000099; background-color:#8DD9E0;"></div>
</td>
<td class=$form_class align=left width="10%"><input class=row1button type=submit name=sort_exists_$sort_order{'exists'} value="&nbsp;Host exists.&nbsp;&nbsp;">
</td>
<td class=$form_class align=left width="1%">
<div style="width:8px; height:8px; border:1px solid #000099; background-color:#FFFFFF;"></div>
</td>
<td class=$form_class align=left width="10%"><input class=row1button type=submit name=sort_good_$sort_order{'good'} value="&nbsp;Good.">
</td>
<td class=$form_class align=left>&nbsp;
</td>
</tr>
</table>
</td>
</tr>
<tr>
<td class=data0>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>
<td class=$form_class allign=left>Sort columns:&nbsp;
<input class=row1button type=submit name=sort_name_$sort_order{'name'} value=Name>&nbsp;
<input class=row1button type=submit name=sort_alias_$sort_order{'alias'} value=Alias>&nbsp;
<input class=row1button type=submit name=sort_address_$sort_order{'address'} value=Address>&nbsp;
<input class=row1button type=submit name=sort_os_$sort_order{'os'} value=OS>&nbsp;
<input class=row1button type=submit name=sort_profile_$sort_order{'profile'} value=Profile>&nbsp;
<input class=row1button type=submit name=sort_other_$sort_order{'other'} value=Other>&nbsp;
</td>
</tr>
</table>
</td>
</tr>
<tr>
<td>
<div class="scroll" style="height: 250px;">
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>);
    my $class = undef;
    foreach my $host (@hosts) {
	unless ($host) { next }
	my @values = split( /$delimiter/, $host_data{$host} );
	if ( $delimiter eq 'tab' ) {
	    @values = split( /\t/, $host_data{$host} );
	}
	unless ( $values[ $fields{'alias'} ] ) {
	    $values[ $fields{'alias'} ] = $values[ $fields{'name'} ];
	}
	if ( $values[ $fields{'name'} ] && $values[ $fields{'address'} ] ) {
	    $class = 'row_good';
	    if ( $exists{ $values[ $fields{'name'} ] } ) {
		$class = 'row_exists';
	    }
	}
	else {
	    $class = 'row_exception';
	}
	my $profile = '&nbsp;---&nbsp;';
	if ( $profiles{ $values[ $fields{'profile'} ] } ) {
	    $profile = $values[ $fields{'profile'} ];
	}
	$host                         =~ s/^\s+|\s+$//g;
	$values[ $fields{'alias'} ]   =~ s/^\s+|\s+$//g;
	$values[ $fields{'address'} ] =~ s/^\s+|\s+$//g;
	$values[ $fields{'os'} ]      =~ s/^\s+|\s+$//g;
	$values[ $fields{'other'} ]   =~ s/^\s+|\s+$//g;
	$detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class="$class" width=15px>
<input type=checkbox name=host_checked value="$host" $checked{$host}>
</td>
<td class="$class" width=100px>$host
<input type=hidden name=host value="$host">
</td>
<td class="$class" width=200px>$values[$fields{'alias'}]
<input type=hidden name="alias_$host" value="$values[$fields{'alias'}]">
</td>
<td class="$class" width=110px>$values[$fields{'address'}]
<input type=hidden name="address_$host" value="$values[$fields{'address'}]">
</td>
<td class="$class" width=150px>$values[$fields{'os'}]
<input type=hidden name="os_$host" value="$values[$fields{'os'}]">
</td>
<td class="$class" width=100px>$profile
<input type=hidden name="profile_$host" value="$profile">
</td>
<td class="$class" width=100px>$values[$fields{'other'}]</td>
</tr>);
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
</table>
</td>
</tr>
</td>
</tr>
<tr>
<td class=data0>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>
<td>
<input class=submitbutton type=button value="Check All" onclick="doCheckAll();">&nbsp;&nbsp;
<input class=submitbutton type=button value="Uncheck All" onclick="doUnCheckAll();">
</td>
</tr>
</table>
</td>
</tr>);

    return $detail;
}

sub form_profiles(@) {
    my $default         = $_[1];
    my $selected        = $_[2];
    my $profiles        = $_[3];
    my $profiles_detail = $_[4];
    my $doc             = $_[5];
    my @profiles        = @{$profiles};
    my %profiles_detail = %{$profiles_detail};
    my %checked         = ();
    my $checked         = undef;
    unless ($selected) { $selected = $default }
    my $detail = qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td>
<div class="scroll" style="height: 150px;">
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>
<td class=row2 colspan=3>Host profile:</td>
<td class=row2>Host groups:</td>
<td class=row2 colspan=2>Service profiles:</td>
</tr>);
    my $row = 1;

    foreach my $profile (@profiles) {
	my $class = undef;
	if ( $row == 1 ) {
	    $class = 'row_lt';
	    $row   = 2;
	}
	elsif ( $row == 2 ) {
	    $class = 'row_dk';
	    $row   = 1;
	}
	$checked = undef;
	if ( $selected eq $profile ) { $checked = 'checked' }
	$detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class="$class" width="3%" valign=top>
<input class=radio type=radio name=host_profile value="$profile" $checked tabindex=></td>
<td class="$class" valign=top>$profile</td>
<td class="$class" valign=top>$profiles_detail{$profile}{'description'}</td>
<td class="$class" valign=top>);
	if ( $profiles_detail{$profile}{'hostgroups'} ) {
	    foreach my $hg ( sort { $a <=> $b } @{ $profiles_detail{$profile}{'hostgroups'} } ) {
		$detail .= "$hg<br>\n";
	    }
	}
	else {
	    $detail .= "&nbsp;\n";
	}
	$detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
</td>
<td class="$class" valign=top>);
	delete $profiles_detail{$profile}{'hostgroups'};
	delete $profiles_detail{$profile}{'description'};
	foreach my $sp ( sort keys %{ $profiles_detail{$profile} } ) {
	    $detail .= "$sp<br>\n";
	}
	$detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
</td>
<td class="$class" valign=top>);
	foreach my $sp ( sort keys %{ $profiles_detail{$profile} } ) {
	    $detail .= "$profiles_detail{$profile}{$sp}<br>\n";
	}
	$detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
</td>
</tr>);
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
</table>
</div>);
    return $detail;
}

sub form_discover() {
    my $oct1 = $_[1];
    my $oct2 = $_[2];
    my $oct3 = $_[3];
    my $oct4 = $_[4];
    my $oct5 = $_[5];
    unless ($oct4) { $oct4 = '*' }
    return qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=data0>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>
<td class=$form_class width="25%">Enter address, range or subnet:</td>
<td class=$form_class>
<input type=text size=4 name=oct1 value=$oct1>&nbsp;.&nbsp;<input type=text size=4 name=oct2 value=$oct2>&nbsp;.&nbsp;<input type=text size=4 name=oct3 value=$oct3>&nbsp;.&nbsp;<input type=text size=4 name=oct4 value=$oct4>&nbsp;-&nbsp;<input type=text size=4 name=oct5 value=$oct5></td>
</tr>
</table>
</td>
</tr>);
}

sub get_file_url(@) {
    my $file = $_[1];
    my $line = $_[2];
    my $url  = '';

    # Security check.
    if (   $file =~ m{^/monarch/workspace/[-a-z0-9._]+$}
	|| $file =~ m{^/profiles/[^./][^/]*$} )
    {
	$url = "$monarch_cgi/monarch_file.cgi?file=$file";
	if ($line) {

	    # Position so the desired line is in the middle, not at the top.
	    $line -= 25;
	    $line = 1 if $line <= 0;
	    $url .= "#line$line";
	}
    }
    return $url;
}

sub filter_results(@) {
    my $results = $_[1];
    foreach (@$results) {
	s{.*}{<font color=#CC0000>$&</font>} if /Error:|Warning:/i;
	my $file = '';
	my $line = 0;
	if (m{(/usr/local/groundwork/core/monarch/workspace/[-a-z0-9._]+).* [lL]ine (\d+)}) {
	    $file = $1;
	    $line = $2;
	}
	elsif (m{(/usr/local/groundwork/core/monarch/workspace/[-a-z0-9._]+)}) {
	    $file = $1;
	}
	if ($file) {
	    ( my $relative_file = $file ) =~ s{/usr/local/groundwork/core}{};
	    my $url = get_file_url( '', $relative_file, $line );
	    s{$file}{<a href="$url" target="_blank"><b><code>$file</code></b></a>};
	}
    }
}

sub get_ajax_url() {
    my $nocache = time;
    return "$monarch_cgi/monarch_ajax.cgi?nocache=$nocache";
}

sub get_scan_url() {
    my $nocache = time;
    return "$monarch_cgi/monarch_scan.cgi?nocache=$nocache";
}

sub scan(@) {
    my $addresses    = $_[1];
    my $elements     = $_[2];
    my $file         = $_[3];
    my $monarch_home = $_[4];
    my @addresses    = @{$addresses};
    my $input_tags   = qq(@{[&$Instrument::show_trace_as_html_comment()]}
<input type=hidden id=file name=file value=$file>
<input type=hidden id=monarch_home name=file value=$monarch_home>);
    my $javascript = qq(@{[&$Instrument::show_trace_as_html_comment()]}
<script type="text/javascript" language=JavaScript>
var ips= new Array($elements));
    @addresses = reverse @addresses;
    my $i = 0;

    foreach my $ip (@addresses) {
	$javascript .= qq(
ips[$i]="$ip";);
	$input_tags .= qq(
<input type=hidden id="$ip" name=ip value=$ip>);
	$i++;
    }
    $javascript .= qq(
function scan_host() {
	var host = ips.pop()
	if (host==undefined) {
		document.getElementById("status").innerHTML = "Finished";
	}
	else {
		document.getElementById("status").innerHTML = host + ' ...';
		get_host( ['file',host,'monarch_home'], [addRow] )
	}
}

function addRow() {
	var args = arguments[0].split('|')
	var tbody = document.getElementById("reportTable").getElementsByTagName("TBODY")[0];
	var row = document.createElement("TR")
	var td1 = document.createElement("TD")
	td1.appendChild(document.createTextNode(args[0]))
	var td2 = document.createElement("TD")
	td2.appendChild(document.createTextNode(args[1]))
	var td3 = document.createElement("TD")
	td3.appendChild(document.createTextNode(args[2]))
	var td4 = document.createElement("TD")
	td4.appendChild(document.createTextNode(args[3]))
	var td5 = document.createElement("TD")
	td5.appendChild(document.createTextNode(args[4]))
	row.appendChild(td1);
	row.appendChild(td2);
	row.appendChild(td3);
	row.appendChild(td4);
	row.appendChild(td5);
	tbody.appendChild(row);
	scan_host()
}
</script>
);

    my $detail = qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=data0>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>
<td class=$form_class valign=top width="20%">Scanning:</td>
<td class=$form_class><div id="status"></div>
</td>
</tr>
</table>
</td>
</tr>
<tr>
<td>
$javascript
$input_tags
<div class="scroll">
<table id="reportTable" width="100%" cellpadding=7 cellspacing=0 align=left border=0>
<tr>
<tbody>
</tbody>
</table>
</tr>
</table>
</div>
</td>
</tr>);
}

sub inheritance(@) {
    my $title    = $_[1];
    my $body     = $_[2];
    my $objects  = $_[3];
    my $tab      = $_[4];
    my $tabindex = $tab ? "tabindex=\"$tab\"" : '';
    my %objects  = %{$objects};
    my $detail   = js_toggle_input();
    (my $template_options_type = $title) =~ s/ /_/g;
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr class=no_border>
<td class=data colspan=3 style="border-width: 0;">
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>);
    if ($title) {
	$detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=wizard_title_heading style="padding: 0.5em 10px;" valign=top>$title</td>
</tr>);
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=wizard_body style="border-color: #FFFFFF; border-style: none; border-width: 2px;">
<table width="100%" cellpadding=7 cellspacing=0 align=left border=0>
<tr>
<td class=wizard_body>
<input class=submitbutton type=submit name=select_all value="Set Full Inheritance" $tabindex>
<!-- GWMON-10837 --><input type=hidden name="$template_options_type\_override" value="0">
</td>
<td class=wizard_body>$body</td>
</tr>
</table>
</td>
</tr>
</table>
</td>
</tr>
<!--
This nearly-empty row, with only one cell (not 3) is a workaround for a Chrome v28
border-collapse rendering bug, that fortunately works in Firefox 17 and IE8 as well.
-->
<tr class=no_border>
<td width="2%"></td>
</tr>);
    return $detail;
}

sub group_main(@) {
    my %group      = %{ $_[1] };
    my %docs       = %{ $_[2] };
    my @members    = @{ $_[3] };
    my @nonmembers = @{ $_[4] };
    my $tab        = $_[5];
    my $tabindex   = $tab ? "tabindex=\"$tab\"" : '';
    my %checked    = ();

    $checked{'inactive'}       = (defined( $group{'status'} ) && $group{'status'} & 1) ? 'checked' : '';
    $checked{'sync_hosts'}     = defined( $group{'status'} ) ? (($group{'status'} & 2) ? 'checked' : '') : 'checked';
    $checked{'use_hosts'}      = $group{'use_hosts'}      ? 'checked' : '';
    $checked{'inherit_host_active_checks_enabled'}     = $group{inherit_host_active_checks_enabled}     ? 'checked' : '';
    $checked{'inherit_host_passive_checks_enabled'}    = $group{inherit_host_passive_checks_enabled}    ? 'checked' : '';
    $checked{'inherit_service_active_checks_enabled'}  = $group{inherit_service_active_checks_enabled}  ? 'checked' : '';
    $checked{'inherit_service_passive_checks_enabled'} = $group{inherit_service_passive_checks_enabled} ? 'checked' : '';
    $checked{'host_active_checks_enabled'}     = ( defined( $group{'host_active_checks_enabled'}     ) && $group{'host_active_checks_enabled'}     eq '1' ) ? 'checked' : '';
    $checked{'host_passive_checks_enabled'}    = ( defined( $group{'host_passive_checks_enabled'}    ) && $group{'host_passive_checks_enabled'}    eq '1' ) ? 'checked' : '';
    $checked{'service_active_checks_enabled'}  = ( defined( $group{'service_active_checks_enabled'}  ) && $group{'service_active_checks_enabled'}  eq '1' ) ? 'checked' : '';
    $checked{'service_passive_checks_enabled'} = ( defined( $group{'service_passive_checks_enabled'} ) && $group{'service_passive_checks_enabled'} eq '1' ) ? 'checked' : '';
    my $sync_class    = $checked{'inactive'} ? 'row1' : 'row1_disabled';
    my $sync_disabled = $checked{'inactive'} ? ''     : 'disabled';
    my $host_active_style     = 'visibility: ' . ($checked{'inherit_host_active_checks_enabled'}     ? 'hidden' : 'visible');
    my $host_passive_style    = 'visibility: ' . ($checked{'inherit_host_passive_checks_enabled'}    ? 'hidden' : 'visible');
    my $service_active_style  = 'visibility: ' . ($checked{'inherit_service_active_checks_enabled'}  ? 'hidden' : 'visible');
    my $service_passive_style = 'visibility: ' . ($checked{'inherit_service_passive_checks_enabled'} ? 'hidden' : 'visible');

    my $detail = qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=data0>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>
<td class=wizard_title_heading style="padding: 0.5em 10px;" valign=top colspan=2>Contact groups</td>
</tr>
<tr>
<td class=$form_class style="padding: 0.5em 10px 0;" valign=top width="40%">$docs{'contactgroups'}</td>
</td>
<td class=$form_class>
<table cellspacing=0 align=left border=0>
<tr>
<td class=$form_class align=left>
<select name=contactgroups id=members size=10 multiple $tabindex>);
    @members = sort { lc($a) cmp lc($b) } @members;
    foreach my $mem (@members) {
	$detail .= "\n<option value=\"$mem\">$mem</option>";
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
</select>
</td>
<td class=$form_class cellpadding=$global_cell_pad align=left>
<table cellspacing=0 cellpadding=3 align=center border=0>
<tr>
<td class=$form_class align=center>
<input class=submitbutton type=button value="Remove >>" onclick="delIt();" $tabindex>
</td>
</tr>
<tr>
<td class=$form_class align=center>
<input class=submitbutton type=button value="&nbsp;&nbsp;<< Add&nbsp;&nbsp;&nbsp;&nbsp;" onclick="addIt();" $tabindex>
</td>
</tr>
</table>
</td>
<td class=$form_class align=left>
<select name=nonmembers id=nonmembers size=10 multiple $tabindex>);
    my $got_mem = undef;
    @nonmembers = sort { lc($a) cmp lc($b) } @nonmembers;
    foreach my $nmem (@nonmembers) {
	foreach my $mem (@members) {
	    if ( $nmem eq $mem ) { $got_mem = 1 }
	}
	if ($got_mem) {
	    $got_mem = undef;
	    next;
	}
	else {
	    $detail .= "\n<option value=\"$nmem\">$nmem</option>";
	}
    }
    my $group_location = $group{'location'};
    $group_location = '' if not defined $group_location;
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
</select>
</td>
</tr>
</table>
</td>
</tr>
</table>
</td>
</tr>);

    my $toggle_functions = qq(
<script type="text/javascript" language=JavaScript>
function toggle_sync_enable() {
    // IE and Safari can't stand to have a JS var be named the same as an HTML element id!
    var el_sync_label = document.getElementById('sync_label');
    var el_inactive;
    var el_sync_hosts;
    with (document.form) {
	for (var i=0; i < elements.length; i++) {
	    if (elements[i].type == 'checkbox') {
		if (elements[i].id == 'inactive') el_inactive = elements[i];
		else if (elements[i].id == 'sync_hosts') el_sync_hosts = elements[i];
	    }
	}
    }
    if (el_inactive.checked) {
	el_sync_hosts.disabled = false;
	el_sync_hosts.checked = false;
	el_sync_label.className = 'row1';
    }
    else {
	el_sync_hosts.disabled = true;
	el_sync_hosts.checked = true;
	el_sync_label.className = 'row1_disabled';
    }
}
function toggle_visibility(check_type) {
    var el_inherit = document.getElementById('inherit_' + check_type + '_checks_enabled');
    var el_visibility = document.getElementById(check_type + '_visibility');
    el_visibility.style.visibility = el_inherit.checked ? 'hidden' : 'visible';
}
</script>);

    $detail .= wizard_doc( '', "Group Status $toggle_functions", $docs{'status'}, undef, 1 );
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=data0>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>
<td class=$form_class width="27%">Set group inactive in Nagios:</td>
<td class=$form_class width="3%" align=center>
<a class=orange href='#doc' title="$docs{'inactive'}" tabindex='-1'>&nbsp;?&nbsp;</a>
</td>
<td class=$form_class>
<input class=row1 type=checkbox name=inactive id=inactive value=1 $checked{'inactive'} onclick="toggle_sync_enable()" $tabindex>
</td>
</tr>
</table>
</td>
</tr>
<tr>
<td class=data0>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>
<td class=$sync_class id=sync_label width="27%">Sync hosts to Foundation:</td>
<td class=$form_class width="3%" align=center>
<a class=orange href='#doc' title="$docs{'sync_hosts'}" tabindex='-1'>&nbsp;?&nbsp;</a>
</td>
<td class=$form_class>
<input class=$form_class type=checkbox name=sync_hosts id=sync_hosts value=2 $checked{'sync_hosts'} $sync_disabled $tabindex>
</td>
</tr>
</table>
</td>
</tr>);

    $detail .= wizard_doc( '', "Build Instance Properties", $docs{'build_instance_properties'}, undef, 1 );
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=data0>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>
<td class=$form_class width="27%">Build folder:</td>
<td class=$form_class width="3%" align=center>
<a class=orange href='#doc' title="$docs{'location'}" tabindex='-1'>&nbsp;?&nbsp;</a>
</td>
<td class=$form_class>
<input type=text size=69 name=location value="$group_location" $tabindex>
</td>
</tr>
</table>
</td>
</tr>
<tr>
<td class=data0>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>
<td class=$form_class width="27%">Nagios etc folder:</td>
<td class=$form_class width="3%" align=center>
<a class=orange href='#doc' title="$docs{'nagios_etc'}" tabindex='-1'>&nbsp;?&nbsp;</a>
</td>
<td class=$form_class>
<input type=text size=69 name=nagios_etc value="$group{'nagios_etc'}" $tabindex>
</td>
</tr>
</table>
</td>
</tr>
<tr>
<td class=data0>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>
<td class=$form_class width="27%">Force hosts:</td></td>
<td class=$form_class width="3%" align=center>
<a class=orange href='#doc' title="$docs{'use_hosts'}" tabindex='-1'>&nbsp;?&nbsp;</a>
</td>
<td class=$form_class>
<input class=row1 type=checkbox name=use_hosts value=1 $checked{'use_hosts'} $tabindex>
</td>
</tr>
</table>
</td>
</tr>
<tr>
<td class=data0>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>
<td class=$form_class width="27%">Host active checks enabled:</td></td>
<td class=$form_class width="3%" align=center>
<a class=orange href='#doc' title="$docs{'host_active_checks_enabled'}" tabindex='-1'>&nbsp;?&nbsp;</a>
</td>
<td class=$form_class>
<input class=row1 type=checkbox name=inherit_host_active_checks_enabled id=inherit_host_active_checks_enabled
  value=1 $checked{'inherit_host_active_checks_enabled'} onclick="toggle_visibility('host_active')" $tabindex>
Inherit &nbsp;&nbsp;
<span id=host_active_visibility style="$host_active_style">
<input class=row1 type=checkbox name=host_active_checks_enabled id=host_active_checks_enabled value=1 $checked{'host_active_checks_enabled'} $tabindex>
Enabled
</span>
</td>
</tr>
</table>
</td>
</tr>
<tr>
<td class=data0>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>
<td class=$form_class width="27%">Host passive checks enabled:</td></td>
<td class=$form_class width="3%" align=center>
<a class=orange href='#doc' title="$docs{'host_passive_checks_enabled'}" tabindex='-1'>&nbsp;?&nbsp;</a>
</td>
<td class=$form_class>
<input class=row1 type=checkbox name=inherit_host_passive_checks_enabled id=inherit_host_passive_checks_enabled
  value=1 $checked{'inherit_host_passive_checks_enabled'} onclick="toggle_visibility('host_passive')" $tabindex>
Inherit &nbsp;&nbsp;
<span id=host_passive_visibility style="$host_passive_style">
<input class=row1 type=checkbox name=host_passive_checks_enabled id=host_passive_checks_enabled value=1 $checked{'host_passive_checks_enabled'} $tabindex>
Enabled
</span>
</td>
</tr>
</table>
</td>
</tr>
<tr>
<td class=data0>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>
<td class=$form_class width="27%">Service active checks enabled:</td></td>
<td class=$form_class width="3%" align=center>
<a class=orange href='#doc' title="$docs{'service_active_checks_enabled'}" tabindex='-1'>&nbsp;?&nbsp;</a>
</td>
<td class=$form_class>
<input class=row1 type=checkbox name=inherit_service_active_checks_enabled id=inherit_service_active_checks_enabled
  value=1 $checked{'inherit_service_active_checks_enabled'} onclick="toggle_visibility('service_active')" $tabindex>
Inherit &nbsp;&nbsp;
<span id=service_active_visibility style="$service_active_style">
<input class=row1 type=checkbox name=service_active_checks_enabled id=service_active_checks_enabled value=1 $checked{'service_active_checks_enabled'} $tabindex>
Enabled
</span>
</td>
</tr>
</table>
</td>
</tr>
<tr>
<td class=data0>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>
<td class=$form_class width="27%">Service passive checks enabled:</td></td>
<td class=$form_class width="3%" align=center>
<a class=orange href='#doc' title="$docs{'service_passive_checks_enabled'}" tabindex='-1'>&nbsp;?&nbsp;</a>
</td>
<td class=$form_class>
<input class=row1 type=checkbox name=inherit_service_passive_checks_enabled id=inherit_service_passive_checks_enabled
  value=1 $checked{'inherit_service_passive_checks_enabled'} onclick="toggle_visibility('service_passive')" $tabindex>
Inherit &nbsp;&nbsp;
<span id=service_passive_visibility style="$service_passive_style">
<input class=row1 type=checkbox name=service_passive_checks_enabled id=service_passive_checks_enabled value=1 $checked{'service_passive_checks_enabled'} $tabindex>
Enabled
</span>
</td>
</tr>
</table>
</td>);
    return $detail;
}

sub group_hosts(@) {
    my $members              = $_[1];
    my $nonmembers           = $_[2];
    my $hostgroup_members    = $_[3];
    my $hostgroup_nonmembers = $_[4];
    my $help_url             = $_[5];
    my %members              = %{$members};
    my %nonmembers           = %{$nonmembers};
    my %hostgroup_members    = %{$hostgroup_members};
    my %hostgroup_nonmembers = %{$hostgroup_nonmembers};

    my $scroll_height = scalar (keys %members) + scalar (keys %hostgroup_members);
    $scroll_height = 10 if ($scroll_height < 10);
    $scroll_height = 20 if ($scroll_height > 20);
    my $detail = qq(@{[&$Instrument::show_trace_as_html_comment()]}
<script type="text/javascript" language=JavaScript>
function doCheckAll()
{
  with (document.form) {
    for (var i=0; i < elements.length; i++) {
	if (elements[i].type == 'checkbox' && (elements[i].name == 'rem_host_checked' || elements[i].name == 'rem_hostgroup_checked'))
	   elements[i].checked = true;
    }
  }
}
function doUnCheckAll()
{
  with (document.form) {
    for (var i=0; i < elements.length; i++) {
	if (elements[i].type == 'checkbox' && (elements[i].name == 'rem_host_checked' || elements[i].name == 'rem_hostgroup_checked'))
	   elements[i].checked = false;
    }
  }
}
</script>
<tr>
<td width="100%" align=center>
<div class="scroll" style="height: ${scroll_height}em;" tabindex='-1'>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>);
    my $row = 1;

    foreach my $host ( sort { lc($a) cmp lc($b) } keys %members ) {
	my $class = undef;
	if ( $row == 1 ) {
	    $class = 'row_lt';
	    $row   = 2;
	}
	elsif ( $row == 2 ) {
	    $class = 'row_dk';
	    $row   = 1;
	}

	$detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class="$class" valign=top width="3%">
<input type=checkbox name=rem_host_checked value="$host">
</td>
<td class="$class" align=left valign=top width="20%" colspan=2><b>$host</b></td>
<td class="$class" align=left valign=top width="10%">host &nbsp;</td>
<td class="$class" align=left valign=top width="70%">$members{$host}{'alias'} &nbsp;</td>
</tr>);
    }

    foreach my $hostgroup ( sort { lc($a) cmp lc($b) } keys %hostgroup_members ) {
	my $class = undef;
	if ( $row == 1 ) {
	    $class = 'row_lt';
	    $row   = 2;
	}
	elsif ( $row == 2 ) {
	    $class = 'row_dk';
	    $row   = 1;
	}
	my $host_text = join ( ', ', @{ $hostgroup_members{$hostgroup} } );
	$detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class="$class" valign=top width="3%">
<input type=checkbox name=rem_hostgroup_checked value="$hostgroup">
</td>
<td class="$class" align=left valign=top width="20%" colspan=2><b>$hostgroup</b></td>
<td class="$class" align=left valign=top width="10%">hostgroup &nbsp;</td>
<td class="$class" align=left valign=top width="70%">$host_text&nbsp;</td>
</tr>);
    }

    $scroll_height = scalar (keys %nonmembers);
    $scroll_height = 10 if ($scroll_height < 10);
    $scroll_height = 20 if ($scroll_height > 20);
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
</table>
</div>
</td>
</tr>
<tr>
<td class=data4>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>
<td>
<input class=submitbutton type=button value="Check All" onclick="doCheckAll();">&nbsp;&nbsp;
<input class=submitbutton type=button value="Uncheck All" onclick="doUnCheckAll();">&nbsp;&nbsp;
<input class=submitbutton type=submit name=remove_host value="Remove">&nbsp;&nbsp;);
    if ($help_url) {
	$detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<input class=submitbutton type=button name=help value="Help" onclick="open_window('$help_url')">);
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
</td>
</tr>
</table>
</td>
</tr>
<tr>
<td width="100%" align=center>
<div class="scroll" style="height: ${scroll_height}em;" tabindex='-1'>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>);
    $row = 1;
    foreach my $host ( sort { lc($a) cmp lc($b) } keys %nonmembers ) {
	my $class = undef;
	if ( $row == 1 ) {
	    $class = 'row_lt';
	    $row   = 2;
	}
	elsif ( $row == 2 ) {
	    $class = 'row_dk';
	    $row   = 1;
	}

	$detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class="$class" valign=top width="3%">
<input type=checkbox name=add_host_checked value="$host">
</td>
<td class="$class" align=left valign=top width="20%" colspan=2><b>$host</b></td>
<td class="$class" align=left valign=top width="77%">$nonmembers{$host}{'alias'}&nbsp;</td>
<td class="$class" align=left valign=top width="37%">$nonmembers{$host}{'address'}&nbsp;</td>
</tr>);
    }

    $scroll_height = scalar (keys %hostgroup_nonmembers);
    $scroll_height = 10 if ($scroll_height < 10);
    $scroll_height = 20 if ($scroll_height > 20);
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
</table>
</div>
</td>
</tr>
<tr>
<td class=data4>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>
<td align=left width="20%">
<input class=submitbutton type=submit name=add_host value="Add Host(s)">
</td>
</tr>
</table>
</td>
</tr>
<tr>
<td width="100%" align=center>
<div class="scroll" style="height: ${scroll_height}em;" tabindex='-1'>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>);
    $row = 1;
    foreach my $hostgroup ( sort { lc($a) cmp lc($b) } keys %hostgroup_nonmembers ) {
	my $class = undef;
	if ( $row == 1 ) {
	    $class = 'row_lt';
	    $row   = 2;
	}
	elsif ( $row == 2 ) {
	    $class = 'row_dk';
	    $row   = 1;
	}
	my $host_text = join ( ', ',  @{ $hostgroup_nonmembers{$hostgroup} } );
	$detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class="$class" valign=top width="3%">
<input type=checkbox name=add_hostgroup_checked value="$hostgroup">
</td>
<td class="$class" align=left valign=top width="20%" colspan=2><b>$hostgroup</b></td>
<td class="$class" align=left valign=top width="77%">$host_text&nbsp;</td>
</tr>);
    }

    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
</table>
</div>
</td>
</tr>
<tr>
<td class=data4>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>
<td align=left width="20%">
<input class=submitbutton type=submit name=add_hostgroup value="Add Hostgroup(s)">
</td>
</tr>
</table>
</td>
</tr>);

    return $detail;
}

sub group_children(@) {
    my $group_hosts = $_[1];
    my $order       = $_[2];
    my $group_child = $_[3];
    my $nonmembers  = $_[4];
    my $help_url    = $_[5];
    my %group_hosts = %{$group_hosts};
    my @order       = @{$order};
    my %group_child = %{$group_child};
    my %nonmembers  = %{$nonmembers};
    my $detail      = qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td width="100%" align=center>
<div class="scroll" style="height: 200px;">
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>);
    my %child_parent = ();
    my $space        = undef;
    my $p_group      = 1;
    my $row          = 1;
    my $class        = undef;
    my %used         = ();

    foreach my $grp (@order) {
	my $childstr  = '';
	my $childdesc = '';
	delete $nonmembers{$grp};
	foreach my $child ( keys %{ $group_child{$grp} } ) {
	    $child_parent{$child} = $grp;
	    $childstr  .= "$child<br>";
	    $childdesc .= "$group_hosts{$child}{'description'}<br>";
	    $used{$child} = 1;
	    delete $nonmembers{$child};
	}
	if ( defined( $child_parent{$grp} ) && $child_parent{$grp} eq $p_group && $childstr ) {
	    $space = "&nbsp;";
	    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class="$class" width="3%">
&nbsp;
<td class="$class\_top" valign=top>
$space<b>&bull;</b>&nbsp;$grp
</td>
<td class="$class\_top" valign=top>
&nbsp;
</td>
<td class="$class\_top" valign=top>
$childstr
</td>
<td class="$class\_top" valign=top>
$childdesc
</td>
</tr>);
	}
	else {
	    if ( $row == 1 ) {
		$class = 'row_lt';
		$row   = 2;
	    }
	    elsif ( $row == 2 ) {
		$class = 'row_dk';
		$row   = 1;
	    }
	    unless ( $used{$grp} ) {
		my $description = defined( $group_hosts{$grp}{'description'} ) ? $group_hosts{$grp}{'description'} : '';
		$detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class="$class" width="3%" valign=top>
<input type=checkbox name=rem_group_checked value="$grp">
<td class="$class" colspan=1 valign=top>
$grp
</td>
<td class="$class" colspan=1 valign=top>
$description
</td>
<td class="$class" valign=top>
$childstr
</td>
<td class="$class" valign=top>
$childdesc
</td>
</tr>);
	    }
	    $space = undef;
	}
	$p_group = $grp;
    }

    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
</table>
</div>
</td>
</tr>
<tr>
<td class=data4>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>
<td>
<input class=submitbutton type=submit name=remove_group value="Remove">&nbsp;&nbsp;);
    if ($help_url) {
	$detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<input class=submitbutton type=button name=help value="Help" onclick="open_window('$help_url')">);
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
</td>
</tr>
</table>
</td>
</tr>
<tr>
<td width="100%" align=center>
<div class="scroll" style="height: 200px;">
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>);
    $row = 1;
    foreach my $child ( sort { lc($a) cmp lc($b) } keys %nonmembers ) {
	my $class = undef;
	if ( $row == 1 ) {
	    $class = 'row_lt';
	    $row   = 2;
	}
	elsif ( $row == 2 ) {
	    $class = 'row_dk';
	    $row   = 1;
	}

	my $description = defined( $nonmembers{$child}{'description'} ) ? $nonmembers{$child}{'description'} : '';
	my $hosts       = defined( $nonmembers{$child}{'hosts'} )       ? $nonmembers{$child}{'hosts'}       : '';
	$detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class="$class" width="3%">
<input type=checkbox name=add_group_checked value="$child">
</td>
<td class="$class" align=left valign=top width="20%" colspan=2><b>$child</b></td>
<td class="$class" align=left valign=top width="37%">$description&nbsp;</td>
<td class="$class" align=left valign=top width="40%">$hosts&nbsp;</td>
</tr>);
    }

    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
</table>
</div>
</td>
</tr>
<tr>
<td class=data4>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>
<td align=left width="20%">
<input class=submitbutton type=submit name=add_group value="Add Group(s)">
</td>
</tr>
</table>
</td>
</tr>);
    return $detail;
}

sub group_macros(@) {
    my $macros        = $_[1];
    my $group_macros  = $_[2];
    my $label_enabled = $_[3];
    my $label         = $_[4];
    my %macros        = %{$macros};
    my %group_macros  = %{$group_macros};
    if ($label_enabled) { $label_enabled = 'checked' }
    my $detail = qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=data0>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>
<td class=$form_class width="3%">
<input type=checkbox name=label_enabled $label_enabled>
</td>
<td class=$form_class align=left width="10%">Enable&nbsp;label</td>
<td class=$form_class align=right width="10%">Value:</td>
<td class=$form_class align=left width="77%"><input type=text name=label size=50 value="$label"></td>
</tr>
</table>
</td>
</tr>
<tr>
<td>
<div class="scroll" style="height: 200px;" tabindex='-1'>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>);
    my $row = 1;

    foreach my $macro ( sort { lc($a) cmp lc($b) } keys %group_macros ) {
	my $class = undef;
	if ( $row == 1 ) {
	    $class = 'row_lt';
	    $row   = 2;
	}
	elsif ( $row == 2 ) {
	    $class = 'row_dk';
	    $row   = 1;
	}
	my $description = defined( $group_macros{$macro}{'description'} ) ? $group_macros{$macro}{'description'} : '';
	my $value       = defined( $group_macros{$macro}{'value'}       ) ? $group_macros{$macro}{'value'}       : '';
	$detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class="$class" width="3%">
<input type=checkbox name=rem_macro_checked value="$macro">
</td>
<td class="$class" align=left width="20%"><b>$macro</b></td>
<td class="$class" align=left width="77%">$description</td>
</tr>
<tr>
<td class="$class" width="3%">&nbsp;</td>
<td class="$class" align=left width="20%" valign=top>Value:</td>
<td class="$class" align=left width="77%"><textarea rows=3 cols=70 name=value_$macro>$value</textarea></td></tr>
</tr>);
    }

    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
</table>
</div>
</td>
</tr>
<tr>
<td class=data4>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>
<td><input class=submitbutton type=submit name=set_values value="Save">&nbsp;&nbsp;
<input class=submitbutton type=submit name=remove_macro value="Remove"></td>
</tr>
</table>
</td>
</tr>);

    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td width="100%" align=center>
<div class="scroll" style="height: 200px;" tabindex='-1'>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>);
    $row = 1;
    foreach my $macro ( sort { lc($a) cmp lc($b) } keys %macros ) {
	my $class = undef;
	if ( $row == 1 ) {
	    $class = 'row_lt';
	    $row   = 2;
	}
	elsif ( $row == 2 ) {
	    $class = 'row_dk';
	    $row   = 1;
	}
	my $description = defined( $macros{$macro}{'description'} ) ? $macros{$macro}{'description'} : '';
	$detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class="$class" width="3%">
<input type=checkbox name=add_macro_checked value="$macro">
</td>
<td class="$class" align=left width="20%" colspan=2><b>$macro</b></td>
<td class="$class" align=left width="77%">$description</td>
</tr>);

    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
</table>
</div>
</td>
</tr>
<tr>
<td class=data4>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>
<td align=left width="20%">
<input class=submitbutton type=submit name=add_macro value="Add Macro(s)">
</td>
</tr>
</table>
</td>
</tr>);
    return $detail;
}

sub macros(@) {
    my $macros   = $_[1];
    my $tab      = $_[2];
    my $tabindex = $tab ? "tabindex=\"$tab\"" : '';
    my %macros   = %{$macros};
    my $lasttab  = $tab + 1;

    my $detail = qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td>
<div class="scroll" style="height: 400px;" tabindex='-1'>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>);
    my $row = 1;
    foreach my $macro ( sort { lc($a) cmp lc($b) } keys %macros ) {
	my $class = undef;
	if ( $row == 1 ) {
	    $class = 'row_lt';
	    $row   = 2;
	}
	elsif ( $row == 2 ) {
	    $class = 'row_dk';
	    $row   = 1;
	}
	my $description = defined( $macros{$macro}{'description'} ) ? $macros{$macro}{'description'} : '';
	my $value       = defined( $macros{$macro}{'value'}       ) ? $macros{$macro}{'value'}       : '';
	$detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class="$class" width="3%"><input type=checkbox name=macro_checked value="$macro" $tabindex></td>
<td class="$class" align=left width="85%" colspan=2><b>$macro</b></td>
<td class="$class" align=left width="12%" rowspan=3><input class=submitbutton type=submit name=rename_$macro value="Rename" $tabindex></td>
</tr><tr>
<td class="$class" width="3%">&nbsp;</td>
<td class="$class" align=left width="10%">Description:</td>
<td class="$class" align=left width="75%"><input type=text size=70 name=description_$macro value="$description" $tabindex></td>
</tr><tr>
<td class="$class" width="3%">&nbsp;</td>
<td class="$class" align=left width="10%" valign=top>Value:</td>
<td class="$class" align=left width="75%"><textarea rows=3 cols=70 name=value_$macro $tabindex>$value</textarea></td>
</tr>);

    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
</table>
</td>
</tr>

<tr>
<td class=data4>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>
<td class=$form_class align=left width="10%">&nbsp;</td>
<td class=$form_class align=left width="10%" colspan=2><b>New Macro</b></td>
<td class=$form_class align=center rowspan=4><input class=submitbutton type=submit name=add value="Add New Macro" tabindex=$lasttab></td>
</tr><tr>
<td class=$form_class align=left width="10%">Macro&nbsp;name:&nbsp;</td>
<td class=$form_class align=left><input type=text size=50 name=name value="" $tabindex></td>
</tr><tr>
<td class=$form_class align=left width="10%">Description:</td>
<td class=$form_class align=left><input type=text size=70 name=description value="" $tabindex></td>
</tr><tr>
<td class=$form_class align=left width="10%" valign=top>Value:</td>
<td class=$form_class align=left><textarea rows=3 cols=70 name=value value="" $tabindex></textarea></td>
</tr>
</table>
</td>
</tr>);

    return $detail;
}

# GWMON-8039 (custom variables)

# Internal routine only.
sub variable_rows (@) {
    my $temp_names    = $_[0];
    my $temp_urls     = $_[1];
    my $temp_vars     = $_[2];
    my $obj_vars      = $_[3];
    my $root_template = $_[4];
    my $object        = $_[5];
    my $default_value = $_[6];
    my $color         = $_[7];
    my $tabindex      = $_[8];
    my $variables     = $object ? $obj_vars : $temp_vars;
    my @detail        = ();

    my @variables = ();
    {
	use locale;
	@variables = sort keys %$variables;
    }

    foreach my $variable (@variables) {
	my @row = ();
	push @row, qq(
	<tr>);
	## Note:  undef values are not expected/allowed here.  If a value exists, it must be defined.
	my $value          = $variables->{$variable};
	my $value_disabled = '';
	if ( not $root_template ) {
	    my $obj_value = $obj_vars->{$variable};
	    my $suppress = defined($obj_value) && $obj_value eq 'null' ? 'checked' : '';
	    push @row, qq(
		<td class="row_$$color" name="row_$variable" align=center><input type=checkbox name="suppress_$variable" value="$variable" onclick="toggle_suppress('$variable')" $suppress $tabindex></td>);
	    if ($object) {
		my $temp_value = $temp_vars->{$variable};
		next if defined($temp_value) && $temp_value ne 'null';
		$value = '' if $suppress;
		push @row, qq(
		    <td class="row_$$color" name="row_$variable"></td>);
	    }
	    else {
		next if $value eq 'null';
		my $inherit = !defined($obj_value) || $obj_value eq 'null' ? 'checked' : '';
		my $inherit_disabled = $suppress ? 'disabled' : '';
		if ( defined($obj_value) && $obj_value ne 'null' ) {
		    $default_value->{$variable} = $value;
		    $value = $obj_value;
		}
		$value_disabled = 'disabled style="background-color: #CCCCCC;"' if $inherit;
		push @row, qq(
		    <td class="row_$$color" align=center><input type=checkbox name="inherit_$variable" value="$variable" onclick="toggle_inherit('$variable')" $inherit $inherit_disabled $tabindex></td>);
	    }
	    $value_disabled = 'disabled style="background-color: #000000;"' if $suppress;
	}
	$value = HTML::Entities::encode($value);
	push @row, qq(
	    <td class="row_$$color" name="row_$variable">$variable<input type=hidden name="$variable" value="$variable"></td>
	    <td class="row_$$color" name="row_$variable"><input type=text size=54 name="value_$variable" value="$value" $value_disabled $tabindex></td>);
	if ($object) {
	    push @row, qq(
		<td class="row_$$color" name="row_$variable" align=right valign=top><input type=button class=removebutton_$$color name="remove_$variable" value="remove" onclick="toggle_variable('$variable')" $tabindex></td>);
	}
	else {
	    push @row, qq(
		<td class="row_$$color" align=left valign=top><a href="$temp_urls->{$variable}">$temp_names->{$variable}</a></td>);
	}
	push @row, qq(
	    </tr>);
	push @detail, @row;
	$$color = $$color eq 'lt' ? 'dk' : 'lt';
    }
    return join( '', @detail );
}

# FIX MINOR:  possibly move this routine to either MonarchStorProc.pm or monarch.cgi
sub resolve_template_variables(@) {
    my $session_id = $_[1];
    my $hash_chain = $_[2];    # arrayref to a series of template-variable-data hashrefs, ordered from leaf to root of the template chain
    my %temp_names = ();
    my %temp_urls  = ();
    my %temp_vars  = ();
    my $now = time;
    foreach my $hashref ( reverse @$hash_chain ) {
	my $menu = $hashref->{menu};
	my $view = $hashref->{view};
	my $type = $hashref->{type};
	my $name = $hashref->{name};
	my $vars = $hashref->{vars};
	foreach my $key ( keys %$vars ) {
	    my $value = $vars->{$key};
	    if ( $value eq 'null' ) {
		delete $temp_names{$key};
		delete $temp_urls {$key};
		delete $temp_vars {$key};
	    }
	    else {
		$temp_names{$key} = $name;
		# FIX MINOR:  Use these values for host and service templates, when we implement them:
		# host template:
		#   menu = 'hosts'
		#   view = 'manage'
		#   type = 'host_templates'
		# service template:
		#   menu = 'services'
		#   view = 'service_template'
		#   type = 'service_templates'
		$temp_urls {$key} =
"$monarch_cgi/monarch.cgi?CGISESSID=$session_id&amp;update_main=1&amp;nocache=$now&amp;top_menu=$menu&amp;view=$view&amp;obj=$type&amp;task=modify&amp;name=$name";
		$temp_vars {$key} = $value;
	    }
	}
    }
    return \%temp_names, \%temp_urls, \%temp_vars;
}

# Paradigm for call:
# %temp_vars contains all applicable higher-level template variables, with all suppressions and overrides between them already resolved
# %obj_vars contains all applicable object variables, which may suppress or override template variables

sub custom_variables(@) {
    my $temp_names    = $_[1];
    my $temp_urls     = $_[2];
    my $temp_vars     = $_[3];
    my $obj_vars      = $_[4];
    my $root_template = $_[5];
    my $doc           = $_[6];
    my $tab           = $_[7];
    local $_;

    my $tabindex = $tab ? "tabindex=\"$tab\"" : '';
    my $next_tab = $tab ? "tabindex=\"" . ( $tab + 1 ) . "\"" : '';

    my $js_root_template = $root_template ? 1 : 0;
    my $detail = qq(
    <tr>
    <td class=data0 colspan=3>
<script type="text/javascript" language=JavaScript>
var root_template = $js_root_template;
var tabindex = '$tabindex';);

    $detail .= q(
function toggle_suppress(varname) {
    var suppress_item = document.getElementsByName("suppress_" + varname)[0];
    var inherit_item  = document.getElementsByName( "inherit_" + varname)[0];
    var value_item    = document.getElementsByName(   "value_" + varname)[0];
    var inherit_checked = false;
    if (inherit_item) {
	inherit_item.disabled = suppress_item.checked;
	inherit_checked = inherit_item.checked;
    }
    value_item.disabled = suppress_item.checked ? true : inherit_checked;
    value_item.style.color = "#000000";
    value_item.style.backgroundColor = suppress_item.checked ? "#000000" : inherit_checked ? "#CCCCCC" : "#FFFFFF";
}
function toggle_inherit(varname) {
    var inherit_item = document.getElementsByName("inherit_" + varname)[0];
    var value_item   = document.getElementsByName(  "value_" + varname)[0];
    if (inherit_item.checked) value_item.value = value_item.defaultValue;
    value_item.disabled = inherit_item.checked;
    value_item.style.color = "#000000";
    value_item.style.backgroundColor = value_item.disabled ? "#CCCCCC" : "#FFFFFF";
}
function toggle_variable(varname) {
    var row_items     = document.getElementsByName(     "row_" + varname);
    var suppress_item = document.getElementsByName("suppress_" + varname)[0];
    var var_item      = document.getElementsByName(              varname)[0].parentNode;
    var value_item    = document.getElementsByName(   "value_" + varname)[0];
    var remove_item   = document.getElementsByName(  "remove_" + varname)[0];
    var remove = (remove_item.value == "remove");
    var rowbgcolor = (var_item.className == 'row_dk') ? "#E2E2E2" : "#FFFFFF";
    for (var i = 0; i < row_items.length; ++i) {
	row_items[i].style.backgroundColor = remove ? "#000000" : rowbgcolor;
    }
    if (suppress_item) suppress_item.disabled = remove;
    value_item.disabled = remove || (suppress_item ? suppress_item.checked : false);
    value_item.style.color = "#000000";
    value_item.style.backgroundColor  = value_item.disabled ? "#000000" : "#FFFFFF";
    remove_item.style.backgroundColor = remove ? "#000000" : rowbgcolor;
    var_item.style.color    = remove ? "#FFFFFF" : "#000000";
    remove_item.style.color = remove ? "#FCC187" : "#FA840F";
    remove_item.value = remove ? "restore" : "remove";
}
function post_error(message) {
    var error_message = document.getElementById('error_message');
    if (!error_message) {
	var error_tbody = document.getElementById('error_tbody');
	for (var i = 0; i < error_tbody.childNodes.length; ++i) {
	    if (error_tbody.childNodes[i].nodeName == 'TR') {
		var tr = document.createElement("tr");
		var td = document.createElement("td");
		td.className = "error";
		td.colSpan = 3;
		td.id = "error_message";
		tr.appendChild(td);
		error_tbody.insertBefore(tr, error_tbody.childNodes[i])
		error_message = td;
		break;
	    }
	}
    }
    error_message.innerHTML = message;
}
function clear_error() {
    var error_message = document.getElementById('error_message');
    if (error_message) {
	var tr = error_message.parentNode;
	tr.parentNode.removeChild(tr);
    }
}
function add_variable() {
    var new_variable_item = document.getElementsByName("new_variable")[0];
    var new_value_item    = document.getElementsByName("new_value"   )[0];
    var variable  = new_variable_item.value;
    var value     = new_value_item.value;

    variable = variable.replace(/^\s\s*/,'').replace(/\s\s*$/,'');
    value = value.replace(/^\s\s*/,'').replace(/\s\s*$/,'');
    if (variable == "") {
	new_value_item.value = value;
	if (value == "") {
	    clear_error();
	}
	else {
	    post_error("Error:  You must specify a variable name.");
	}
	return;
    }

    // Perl \p{IsWord} chars within ISO-8859-1, reflected in the long pattern below:
    // \u0030-\u0039 0-9
    // \u0041-\u005A A-Z
    // \u005F-\u005F _-_
    // \u0061-\u007A a-z
    // \u00AA-\u00AA ª-ª
    // \u00B2-\u00B3 ²-³
    // \u00B5-\u00B5 µ-µ
    // \u00B9-\u00BA ¹-º
    // \u00BC-\u00BE ¼-¾
    // \u00C0-\u00D6 À-Ö
    // \u00D8-\u00F6 Ø-ö
    // \u00F8-\u00FF ø-ÿ
    // Try using the lucidasanstypewriter-bold-14 font if some of these chars won't display properly in your editor.

    var pattern = /^_/;
    if (!pattern.test(variable)) {
	post_error("Error:  The variable name does not start with an underscore.");
	return;
    }
    pattern = /^_\S/;
    if (!pattern.test(variable)) {
	post_error("Error:  The variable name must contain at least one character after the initial underscore.");
	return;
    }
    pattern = /[^\u0000-\u00FF]/;
    if (pattern.test(variable)) {
	post_error("Error:  Only ISO-8859-1 (Latin-1, 8-bit) characters are allowed in variable names.");
	return;
    }
    pattern = /^_[\w\u00AA\u00B2-\u00B3\u00B5\u00B9-\u00BA\u00BC-\u00BE\u00C0-\u00D6\u00D8-\u00F6\u00F8-\u00FF]+$/;
    if (!pattern.test(variable)) {
	post_error("Error:  The variable name contains illegal characters.");
	return;
    }
    pattern = /[^\u0000-\u00FF]/;
    if (pattern.test(value)) {
	post_error("Error:  Only ISO-8859-1 (Latin-1, 8-bit) characters are allowed in values.");
	return;
    }

    // FIX LATER:  If we insert the row in sorted position, that sort must only be in the objects portion, which we
    // might use a separate tbody for (unless our comparison takes into account not just the varname but also which
    // section it resides in); but we will still need to check for duplicates in the templates portion too.
    var variable_tbody = document.getElementById('variable_tbody');
    var input_items    = variable_tbody.getElementsByTagName("input");
    var duplicate      = false;
    var row_count      = 0;
    for (var i = 0; i < input_items.length; ++i) {
	var input_name = input_items[i].name;
	if (/^_/.test(input_name)) {
	    ++row_count;
	    if (variable == input_name) {
		duplicate = true;
	    }
	}
    }
    if (duplicate) {
	post_error('Error:  Variable name "'+variable+'" is already in use.  Use the controls above to adjust its value.');
	return;
    }
    clear_error();

    if (variable_tbody.rows[variable_tbody.rows.length - 1].cells[0].innerHTML == 'None defined.') {
	variable_tbody.deleteRow(variable_tbody.rows.length - 1);
    }

    // FIX LATER:  Insert not at the end, but at a sorted position, using String.localeCompare(); then must recolor all rows below that point.
    // Note that Perl sorts on the server, while this JavaScript would sort on the client, and the collation orders might be different.
    var tr        = variable_tbody.insertRow(variable_tbody.rows.length);
    var color     = (row_count % 2) ? 'dk' : 'lt';
    var row_color = 'row_' + color;
    var td;

    var value_disabled = '';
    if ( !root_template ) {
	var suppress = (value != null && value == 'null') ? 'checked' : '';

	if (suppress) {
	    value = '';
	    value_disabled = 'disabled style="background-color: #000000;"';
	}

	td           = tr.insertCell(tr.cells.length);
	td.className = row_color;
	td.setAttribute('name', 'row_'+variable);
	td.align     = 'center';
	td.innerHTML = '<input type=checkbox name="suppress_'+variable+'" value="'+variable+'" onclick="toggle_suppress(\''+variable+'\')" '+suppress+' '+tabindex+'>';

	td           = tr.insertCell(tr.cells.length);
	td.className = row_color;
	td.setAttribute('name', 'row_'+variable);
    }

    value = value.replace(/&/g, '&amp;');
    value = value.replace(/'/g, '&#39;');
    value = value.replace(/"/g, '&quot;');
    value = value.replace(/</g, '&lt;');
    value = value.replace(/>/g, '&gt;');

    td           = tr.insertCell(tr.cells.length);
    td.className = row_color;
    td.setAttribute('name', 'row_'+variable);
    td.innerHTML = variable+'<input type=hidden name="'+variable+'" value="'+variable+'">';

    td           = tr.insertCell(tr.cells.length);
    td.className = row_color;
    td.setAttribute('name', 'row_'+variable);
    td.innerHTML = '<input type=text size=54 name="value_'+variable+'" value="'+value+'" '+value_disabled+' '+tabindex+'>';

    td           = tr.insertCell(tr.cells.length);
    td.className = row_color;
    td.setAttribute('name', 'row_'+variable);
    td.align     = 'right';
    td.valign    = 'top';
    td.innerHTML = '<input type=button class=removebutton_'+color+' name="remove_'+variable+'" value="remove" onclick="toggle_variable(\''+variable+'\')" '+tabindex+'>';

    new_variable_item.value = '';
    new_value_item.value    = '';
}
</script>);
    $detail .= qq(
    <table width="100%" cellpadding=7 cellspacing=0 align=left border=0>
	<tr>
	<td class=wizard_title_heading>Custom Object Variables</td>
	</tr>
	<tr>
	<td class=row1>$doc</td>
	</tr>
	<tr>
	<td>
	<table width="100%" cellpadding=3 cellspacing=0 align=left border=0>
	<tbody id=variable_tbody>
	<tr>);
    if ( not $root_template ) {
	$detail .= qq(
	    <td class=column_head align=left width="5%">Suppress</td>
	    <td class=column_head align=left width="5%">Inherit</td>);
    }
    $detail .= qq(
	<td class=column_head align=left>Name</td>
	<td class=column_head align=left>Value</td>
	<td class=column_head align=left>Template</td>
	</tr>);

    my %default_value = ();
    my $color         = 'lt';
    $detail .= variable_rows( $temp_names, $temp_urls, $temp_vars, $obj_vars, $root_template, 0, \%default_value, \$color, $tabindex ) if %$temp_vars;
    $detail .= variable_rows( $temp_names, $temp_urls, $temp_vars, $obj_vars, $root_template, 1, \%default_value, \$color, $tabindex ) if %$obj_vars;
    unless ( %$temp_vars || %$obj_vars ) {
	$detail .= qq(
	<tr>
	<td class=row_lt colspan=5>None defined.</td>
	</tr>);
    }
    $detail .= qq(
	</tbody>
	</table>);
    if (%default_value) {
	foreach my $key (keys %default_value) {
	    $default_value{$key} =~ s/([\\'])/\\$1/g;
	}
	my $default_values = join(',', map { "'$_': '$default_value{$_}'" } keys %default_value);
	$detail .= qq(
<script type="text/javascript" language=JavaScript>
function SetDefaults() {
    var default_value = {$default_values};
    for (var varname in default_value) {
	var value_item = document.getElementsByName("value_" + varname)[0];
	// Setting the defaultValue alone would wipe out the current value.
	value_item.value = value_item.defaultValue;
	value_item.defaultValue = default_value[varname];
    }
}
SafeAddOnload(SetDefaults);
</script>);
    }
    $detail .= qq(
	<table width="100%" cellpadding=4 cellspacing=0 align=left border=0 style="margin-top: 7px;">
	<tr>
	<td class=row2>
	    <table width="100%" cellpadding=3 cellspacing=0 align=left border=0>
	    <tbody id=error_tbody>
	    <tr>
	    <td class=row2 colspan=3>
	    Each variable name must begin with an underscore ("_"), contain at least one other character,
	    and consist only of letters, numbers, and underscores.
	    Leading and trailing space in both the name and value will be ignored.
	    </td>
	    </tr>
	    <tr>
	    <td class=row2>Variable&nbsp;name:&nbsp;</td>
	    <td class=row2 align=left><input type=text size=30 name=new_variable value="" $tabindex></td>
	    <td rowspan=2 class=row2 align=left width="65%">&nbsp;&nbsp;<input class="submitbutton" type="button" value="Add" onclick="add_variable()" $next_tab></td>
	    </tr>
	    <tr>
	    <td class=row2>Value:&nbsp;</td>
	    <td class=row2 align=left><input type=text size=54 name=new_value value="" $tabindex></td>
	    </tr>
	    </tbody>
	    </table>
	</td>
	</tr>
	</table>
    </td>
    </tr>
    </table>
</td>
</tr>);
}

sub main_cfg_misc(@) {
    my %misc_vals  = %{ $_[1] };
    my $misc_name  = $_[2];
    my $misc_value = $_[3];
    my $doc        = $_[4];
    my $tab        = $_[5];
    my $tabindex   = $tab ? "tabindex=\"$tab\"" : '';
    my $detail     = qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=data0>
<table width="100%" cellspacing=7 align=left border=0>
<tr>
<td class=wizard_body colspan=3>
<table width="100%" cellpadding=0 cellspacing=0 align=left border=0>
<tr>
<td>
$doc
</td>
</tr>
</table>
</td>
</tr>);

    if (%misc_vals) {
	$detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<script type="text/javascript" language=JavaScript>
function doCheckAll()
{
  with (document.form) {
    for (var i=0; i < elements.length; i++) {
	if (elements[i].type == 'checkbox' && elements[i].name == 'rem_key')
	   elements[i].checked = true;
    }
  }
}
function doUnCheckAll()
{
  with (document.form) {
    for (var i=0; i < elements.length; i++) {
	if (elements[i].type == 'checkbox' && elements[i].name == 'rem_key')
	   elements[i].checked = false;
    }
  }
}
</script>
<tr>
<td>
<table width="100%" cellpadding=3 cellspacing=0 align=left border=0>
<tr>
<td class=column_head valign=top width="3%">&nbsp</td>
<td class=column_head align=left valign=top width="20%">Name</td>
<td class=column_head align=left valign=top width="77%">Value</td>
</tr>);
	my $row = 1;
	foreach my $key ( sort keys %misc_vals ) {
	    my $class = undef;
	    if ( $row == 1 ) {
		$class = 'row_lt';
		$row   = 2;
	    }
	    elsif ( $row == 2 ) {
		$class = 'row_dk';
		$row   = 1;
	    }
	    my $value = defined( $misc_vals{$key}{'value'} ) ? $misc_vals{$key}{'value'} : '';
	    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class="$class" valign=top width="3%">
<input type=checkbox name=rem_key value=$key $tabindex>
</td>
<td class="$class" align=left valign=top width="20%">$misc_vals{$key}{'name'}&nbsp;&nbsp;</td>
<td class="$class" align=left valign=top width="77%">
<input type=text size=70 name="$key" value="$value" $tabindex>
</td>
</tr>
);
	}

	$detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
</table>
</td>
</tr>
<tr>
<td class=data2 colspan=3>
<input class=submitbutton type=button value="Check All" onclick="doCheckAll();" $tabindex>&nbsp;&nbsp;
<input class=submitbutton type=button value="Uncheck All" onclick="doUnCheckAll();" $tabindex>&nbsp;&nbsp;
<input class=submitbutton type=submit name=rem_misc value="Remove Directive(s)" $tabindex>
</td>
</tr>);
    }
    $detail .= qq(@{[&$Instrument::show_trace_as_html_comment()]}
<tr>
<td class=top_border width="100%" colspan=3>
<table width="100%" cellpadding=0 cellspacing=7 border=0>
<tr>
<td align="right">Directive&nbsp;name:</td>
<td align="left"><input type=text size=20 name=misc_name value="$misc_name" $tabindex></td>
<td align="right">&nbsp;&nbsp;&nbsp;Value:</td>
<td align="left"><input type=text size=50 name=misc_value value="$misc_value" $tabindex></td>
<td width="50%"></td>
</tr>
<tr>
<td class=row2 valign=top colspan=3>
<input class=submitbutton type=submit name=add_misc value="Add Directive" $tabindex>
</td>
</tr>
</table>
</td>
</tr>
</table>
</td>
</tr>);

    return $detail;
}

#
#############################
# Nagios 3 edit time period
#############################
#

sub time_period_detail(@) {
    my %time_period  = %{ $_[1] };
    my %time_periods = %{ $_[2] };
    my $tab          = $_[3];
    my $tabindex     = $tab ? "tabindex=\"$tab\"" : '';
    my $detail .= qq(
<tr>
<td class=data0>
<table width="100%" cellpadding=7 cellspacing=0 align=left border=0>
    <tr>
    <td class=wizard_title_heading style="padding: 0.5em 8px;" valign=top>Weekdays</td>
    </tr>
    <td class=wizard_body>
The weekday directives (<i>Sunday</i> through <i>Saturday</i>) are comma-delimited lists of time ranges that are "valid" times for a particular day of the week.  Notice that there are seven different days for which you can define time ranges (Sunday through Saturday).  Each time range is in the form of <b>HH:MM-HH:MM</b>, where hours are specified on a 24 hour clock.  For example, <b>00:15-24:00</b> means 12:15 in the morning for this day until 12:00 midnight (a 23 hour, 45 minute total time range).  If you wish to exclude an entire day from the time period, simply do not include it in the time period definition.
    </td>
    </tr>
    <!--
    </table>
    </td>
    </tr>
    <tr>
    <td class=data0>
    <table width="100%" cellpadding=7 cellspacing=0 align=left border=0>
    -->
    <tr>
    <td>
    <table width="100%" cellpadding=3 cellspacing=0 align=left border=0>
	<tr>
	<td class=column_head align=left width="22%">Name</td>
	<td class=column_head align=left width="35%">Hours</td>
	<td class=column_head align=left width="35%">Description</td>
	<td class=column_head align=right width="8%">&nbsp;</td>
	</tr>);
    my $row      = 1;
    my %got_day  = ();
    my @weekdays = ( 'sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday' );
    foreach my $day (@weekdays) {
	my $class = undef;

	if ( $time_period{'weekday'}{$day} ) {
	    $got_day{$day} = 1;
	    if ( $row == 1 ) {
		$class = 'row_lt';
		$row   = 2;
	    }
	    elsif ( $row == 2 ) {
		$class = 'row_dk';
		$row   = 1;
	    }
	    my $hours_style = '';
	    if ( exists $time_period{'weekday'}{$day}{'bad_hours'} ) {
		$hours_style = 'style="background-color: #FFFF99;"';
	    }
	    my $comment = defined( $time_period{'weekday'}{$day}{'comment'} ) ? $time_period{'weekday'}{$day}{'comment'} : '';
	    $detail .= qq(
	<tr>
	<td class="$class" valign=top><input type=hidden name=weekday_$day value=1>\u$day</td>
	<td class="$class"><input $hours_style type=text size=40 name=value_$day value="$time_period{'weekday'}{$day}{'value'}" $tabindex></td>
	<td class="$class"><input type=text size=40 name=comment_$day value="$comment" $tabindex></td>
	<td class="$class" align=right valign=top><input type=submit class="$class" name="remove_weekday_$day" value="remove" $tabindex></td>
	</tr>);
	}
    }
    unless ( keys %{ $time_period{'weekday'} } ) {
	$detail .= qq(
	<tr>
	<td class=row_lt colspan=4>None defined</td>
	</tr>);
    }
    $detail .= qq(
    </table>
    </td>
    </tr>
    <tr>
    <td>
    <table width="100%" cellpadding=7 cellspacing=0 align=left border=0>
	<tr>
	<td class=row2>
	<table width="100%" cellpadding=0 cellspacing=0 align=left border=0>
	    <tr>
	    <td class=row2 width="55">
	    <select name=new_day $tabindex>);
    my $options = undef;
    foreach my $day (@weekdays) {
	unless ( $got_day{$day} ) {
	    $options .= qq(<option value="$day">\u$day</option>);
	}
    }
    unless ($options) {
	$options .= qq(<option name="no_days" value="">Nothing to add</option>);
    }

    $detail .= qq(
$options
	    </select tabindex=16>
	    </td>
	    <td class=row2_padded valign=top width="40" align=left><input class="submitbutton" type="submit" name="add_day" value="Add" $tabindex></td>
	    <td class=row2_padded>Select a day and click Add to set the hours.</td>
	    </td>
	    </tr>
	</table>
	</td>
	</tr>
    </table>
    </td>
    </tr>
</table>
</td>
</tr>
    <tr>
    <td class=data0>
    <table width="100%" cellpadding=7 cellspacing=0 align=left border=0>
	<tr>
	<td class=wizard_title_heading>Exceptions (Advanced)</td>
	</tr>
	<td class=wizard_body>
	    You can specify several different types of exceptions to the standard rotating weekday schedule.
	    <p class=append>
	    Exceptions can take a number of different forms including single days of a specific or generic month, single weekdays in a month, or single calendar dates.  You can also specify a range of days/dates and even specify skip intervals to obtain functionality described by "every 3 days between these dates".
	    </p><p class=append>
	    Examples:
	    </p><p class=append>
	    <table cellspacing=3 border=0>
	    <tr><td style="padding-right:5px">2010-01-28</td><td>00:00-24:00</td><td>&mdash; January 28th, 2010</td></tr>
	    <tr><td style="padding-right:5px">monday 3</td><td>00:00-24:00</td><td>&mdash; 3rd Monday of every month</td></tr>
	    <tr><td style="padding-right:5px">day 2</td><td>00:00-24:00</td><td>&mdash; 2nd day of every month</td></tr>
	    <tr><td style="padding-right:5px">february 10</td><td>00:00-24:00</td><td>&mdash; February 10th of every year</td></tr>
	    <tr><td style="padding-right:5px">february -1</td><td>00:00-24:00</td><td>&mdash; Last day in February of every year</td></tr>
	    <tr><td style="padding-right:5px">friday -2</td><td>00:00-24:00</td><td>&mdash; 2nd to last Friday of every month</td></tr>
	    <tr><td style="padding-right:5px">thursday -1 november</td><td>00:00-24:00</td><td>&mdash; Last Thursday in November of every year</td></tr>
	    </table>
	    </p><p class=append>
	    Visit <a href="http://nagios.sourceforge.net/docs/3_0/objectdefinitions.html#timeperiod" target="_blank" tabindex='-1'>http://nagios.sourceforge.net/docs/3_0/objectdefinitions.html#timeperiod</a>
	    for more examples of what can be accomplished.
	    </p><p class=append>
	    Weekdays and different types of exceptions all have different levels of precedence, so it's important to understand how they can affect each other.
	    </p><p class=append>
	    Precedence:
	    </p><p class=append>
	    <ol>
	    <li>Specific month date (January 1st)</li>
	    <li>Generic month date (Day 15)</li>
	    <li>Offset weekday of specific month (2nd Tuesday in December)</li>
	    <li>Offset weekday (3rd Monday)</li>
	    <li>Weekday</li>
	    </ol>
	    </p><p class=append>
	    More information on this can be found in the documentation at
	    <a href="http://nagios.sourceforge.net/docs/3_0/timeperiods.html" target="_blank" tabindex='-1'>http://nagios.sourceforge.net/docs/3_0/timeperiods.html</a> .
	    </p>
	</td>
	</tr>
	<!--
	</table>
	</td>
	</tr>
	<tr>
	<td class=data0>
	<table width="100%" cellpadding=7 cellspacing=0 align=left border=0>
	-->
	<tr>
	<td>
	<table width="100%" cellpadding=3 cellspacing=0 align=left border=0>
	<tr>
	<td class=column_head align=left>Day Rule</td>
	<td class=column_head align=left>Hours</td>
	<td class=column_head align=left>Description</td>
	<td class=column_head align=right>&nbsp;</td>
	</tr>);
    $row = 1;
    foreach my $excp ( sort keys %{ $time_period{'exception'} } ) {
	my $class = undef;
	if ( $row == 1 ) {
	    $class = 'row_lt';
	    $row   = 2;
	}
	elsif ( $row == 2 ) {
	    $class = 'row_dk';
	    $row   = 1;
	}
	my $day_rule_style = '';
	if ( exists $time_period{'exception'}{$excp}{'bad_day_rule'} ) {
	    $day_rule_style = 'style="background-color: #FFFF99;"';
	}
	my $hours_style = '';
	if ( exists $time_period{'exception'}{$excp}{'bad_hours'} ) {
	    $hours_style = 'style="background-color: #FFFF99;"';
	}
	my $comment = defined( $time_period{'exception'}{$excp}{'comment'} ) ? $time_period{'exception'}{$excp}{'comment'} : '';
	$detail .= qq(
	<tr>
	<td class="$class" valign=top><input $day_rule_style type=text size=39 name="exception_$excp" value="$excp" $tabindex></td>
	<td class="$class"><input $hours_style type=text size=34 name="value_$excp" value="$time_period{'exception'}{$excp}{'value'}" $tabindex></td>
	<td class="$class"><input type=text size=29 name="comment_$excp" value="$comment" $tabindex></td>
	<td class="$class" align=right valign=top><input type=submit class="$class" name="remove_exception_$excp" value="remove" $tabindex></td>
	</tr>);
    }
    unless ( keys %{ $time_period{'exception'} } ) {
	$detail .= qq(
	<tr>
	<td class=row_lt colspan=4>None defined</td>
	</tr>);
    }
    $detail .= qq(
    </table>
    </td>
    </tr>
    <tr>
    <td>
    <table width="100%" cellpadding=7 cellspacing=0 align=left border=0>
	<tr>
	<td class=row2>
	<table width="100%" cellpadding=0 cellspacing=0 align=left border=0>
	    <tr>
	    <td class=row2 width="60">New&nbsp;day&nbsp;rule:&nbsp;</td>
	    <td class=row2 width="260" align=left><input type=text size=50 name=new_exception value="" $tabindex></td>
	    <td class=row2_padded width="40" align=left><input class="submitbutton" type="submit" name="add_exception" value="Add" $tabindex></td>
	    <td class=row2_padded align=left>Enter a new Day Rule and click Add to set the hours.</td>
	    </tr>
	</table>
	</td>
	</tr>
    </table>
    </td>
    </tr>
</table>
</td>
</tr>
    <tr>
    <td class=data0>
    <table width="100%" cellpadding=7 cellspacing=0 align=left border=0>
	<tr>
	<td class=wizard_title_heading>Exclude</td>
	</tr>
	<tr>
	<td class=row1>
This directive is used to specify other timeperiod definitions whose time ranges should be excluded from this timeperiod.
	</td>
	</tr>
	<tr>
	<td>
	<table width="100%" cellpadding=3 cellspacing=0 align=left border=0>
	    <tr>
	    <td class=column_head align=right width="2%">&nbsp;</td>
	    <td class=column_head align=left  width="24%">Time Period Name</td>
	    <td class=column_head align=left  width="37%">Alias</td>
	    <td class=column_head align=left  width="37%">Description</td>
	    </tr>);
    $row = 1;
    foreach my $tname ( sort keys %time_periods ) {
	my $checked = '';
	if ( $tname eq $time_period{'name'} ) { next }
	foreach my $id ( keys %{ $time_period{'exclude'} } ) {
	    $checked = 'checked' if $id eq $time_periods{$tname}{'id'};
	}
	my $class = undef;
	if ( $row == 1 ) {
	    $class = 'row_lt';
	    $row   = 2;
	}
	elsif ( $row == 2 ) {
	    $class = 'row_dk';
	    $row   = 1;
	}
	my $comment = defined( $time_periods{$tname}{'comment'} ) ? $time_periods{$tname}{'comment'} : '';
	$detail .= qq(
	    <tr>
	    <td class="$class" align=right width=15px><input type="checkbox" name="exclude" value="$time_periods{$tname}{'id'}" $checked $tabindex></td>
	    <td class="$class" align=left width=200px>$tname</td>
	    <td class="$class" align=left width=300px>$time_periods{$tname}{'alias'}</td>
	    <td class="$class" align=left width=300px>$comment</td>
	    </tr>);
    }
    unless ( keys %time_periods ) {
	$detail .= qq(<tr><td class=row_lt colspan=4>None defined</td></tr>);
    }
    $detail .= qq(
	</table>
	</td>
	</tr>
    </table>
    </td>
    </tr>);

    return $detail;
}

#
#############################
# NMS Integration
#############################
#

sub login_redirect() {
    return qq(
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<html>
<head>
<title>Monarch</title>
<meta http-equiv="X-UA-Compatible" content="IE=edge">
<META HTTP-EQUIV="CONTENT-TYPE" CONTENT="text/html; charset=utf-8">
<META HTTP-EQUIV="Pragma" CONTENT="no-cache">
<META HTTP-EQUIV="Expires" CONTENT="-1">
<link rel="stylesheet" type="text/css" href="$monarch_css/monarch.css">
<link rel="StyleSheet" href="$monarch_css/dtree.css" type="text/css">
</head>
<body bgcolor="#ffffff">
<!-- generated by: MonarchForms::login_redirect() -->
<table width="100%" cellpadding=0 cellspacing=0 border=0 style="border-collapse: collapse; border-style: solid; border-width: 0;">
<tr>
<td class=data0>
<table width="100%" cellpadding=7 cellspacing=0 align=left border=0>
<tr>
<td class=head>Session Timeout</td>
</tr>
</table>
</td>
</tr>
<tr>
<td class=data0>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>
<td class=row1>Please <a href="$monarch_cgi/$cgi_exe?view=logout" target=_top>login</a>.</td>
</tr>
</table>
</td>
</tr>
</table>
</body>
<script type="text/javascript" language=javascript1.1 src="$monarch_js/monarch.js"></script>
<script type="text/javascript" language=JavaScript src="$monarch_js/nicetitle.js"></script>
<script type="text/javascript" language=JavaScript src="$monarch_js/DataFormValidator.js"></script>
</html>
);

}

sub login(@) {
    my $title   = $_[1];
    my $message = $_[2];
    if ($message) {
	$message = "&dagger;&nbsp;<b>$message</b><br><br>";
    }
    else {
	$message = undef;
    }
    # FIX MINOR:  the /monarch/images/... references here are probably broken
    return qq(
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<HTML>
<HEAD>
<title>Monarch</title>
<meta http-equiv="X-UA-Compatible" content="IE=edge">
<META HTTP-EQUIV="CONTENT-TYPE" CONTENT="text/html; charset=utf-8">
<META HTTP-EQUIV="Pragma" CONTENT="no-cache">
<META HTTP-EQUIV="Expires" CONTENT="-1">
<link rel="stylesheet" type="text/css" href="$monarch_css/monarch.css">
<script type="text/javascript" language=JavaScript src="$monarch_js/DataFormValidator.js"></script>
<script type="text/javascript" language=JavaScript>
	function set_focus() {
		document.getElementById('user_acct').focus();
		return false;
	}
</script>
</HEAD>
<body bgcolor="#999999" onload="set_focus()">
<!-- generated by: MonarchForms::login() -->
<table align=center width=800px cellspacing=0 cellpadding=0 border=0 bgcolor="#EEEEEE">
<tr>
<td><img src="/monarch/images/logo5.png" border=0 align=left></td>
</tr>
<tr>
<td><img src="/monarch/images/home.jpg" border=0></td>
</tr>
<tr>
<td>
<table align=center width=800px cellspacing=3 cellpadding=5 border=0 bgcolor="#EEEEEE">
<tr>
<td width=500px valign=top><br>
<h1>About GroundWork Monitor Architect</h1>
GroundWork Monitor Architect is a web-based configuration tool for Nagios. Features in version 4.5 include:<ul>
<li><p class=append>Support for the PostgreSQL database</p></li>
<li><p class=append>Custom Object Variables for Contacts and Hosts</p></li>
<li><p class=append>Distributed agents reporting to Child Servers</p></li>
<li><p class=append>Support for most Western European languages</p></li>
</ul>
<h1>Support:</h1>Visit GroundWork's support forums at:
<a href="http://www.gwos.com/forums" tabindex='-1'>www.gwos.com/forums</a>
</td>
<td valign=top>
<form name=form action="$monarch_cgi/$cgi_exe" method=post generator=login>
<table border="0" cellpadding="0" cellspacing="0">
<tr>
<td class="columnSpan01"><br><h1>Please log in</h1>
If you do not have an account, contact your Administrator.<br><br>$message
</td>
</tr>
<tr>
<td><span class="formHeader">Username</span></td>
</tr>
<tr>
<td><input type="text" size="50" name="user_acct" id="user_acct" value="" tabindex='1'></td>
</tr>
<tr>
<td><br><span class="formHeader">Password</span></td>
</tr>
<tr>
<td><input type="password" size="30" name="password" tabindex='2'><input type=hidden name=process_login value=1></td>
</tr>
<tr>
<td><br><input class="submitbutton" type="submit" value="Login"></td>
</tr>
</table>
</form>
</td>
</tr>
</table>
</td>
</tr>
<table align=center width=800px cellspacing=0 cellpadding=0 border=0 bgcolor="#EEEEEE">
<tr>
<td>
<hr>
</td>
</tr>
</table>
</td>
</tr>
<tr>
<td>
<table align=center width=800px cellspacing=3 cellpadding=5 border=0 bgcolor="#EEEEEE">
<tr>
<td nowrap="nowrap" class="login_footer" valign="top">
<span class="login_footerHeader">GroundWork Inc.</span><br>
	San Francisco, CA 94107<br>
	USA
</td>
<td nowrap="nowrap" class="login_footer" valign="top">
phone +1 866-899-4342<br>
fax +1 866-414-7358<br>
<a href="http://www.gwos.com/">www.gwos.com</a>
</td>
<td nowrap="nowrap" class="login_footer" valign="top">
&copy; 2016<br>
GroundWork Inc.<br>
All rights reserved.
</td>
<tr>
<td colspan=3>
&nbsp;
</td>
</tr>
</table>
</td>
</tr>
</table>
</BODY>
</HTML>);
}

sub unindent {
    $_[0] =~ s/^[\n\r]*//;
    my ($indent) = ( $_[0] =~ /^([ \t]+)/ );
    $_[0] =~ s/^$indent//gm;
}

1;

