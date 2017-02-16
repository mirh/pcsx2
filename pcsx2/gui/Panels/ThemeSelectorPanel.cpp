/*  PCSX2 - PS2 Emulator for PCs
 *  Copyright (C) 2002-2010  PCSX2 Dev Team
 *
 *  PCSX2 is free software: you can redistribute it and/or modify it under the terms
 *  of the GNU Lesser General Public License as published by the Free Software Found-
 *  ation, either version 3 of the License, or (at your option) any later version.
 *
 *  PCSX2 is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
 *  without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
 *  PURPOSE.  See the GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License along with PCSX2.
 *  If not, see <http://www.gnu.org/licenses/>.
 */

#include "PrecompiledHeader.h"
#include "App.h"
#include "ConfigurationPanels.h"

#include <wx/dir.h>
#include <wx/filepicker.h>
#include <wx/listbox.h>
#include <wx/zipstrm.h>
#include <memory>

using namespace pxSizerFlags;

// =====================================================================================================
//  ThemeSelectorPanel
// =====================================================================================================
Panels::ThemeSelectorPanel::ThemeSelectorPanel( wxWindow* parent )
	: _parent( parent )
{
	SetMinWidth( 480 );

	m_ComboBox		= new wxListBox( this, wxID_ANY, wxDefaultPosition, wxDefaultSize, 0, NULL, wxLB_SINGLE | wxLB_SORT | wxLB_NEEDED_SB );
	m_FolderPicker	= new DirPickerPanel( this, FolderId_Themes,
		_("Themes Search Path:"),							// static box label
		_("Select folder containing PCSX2 visual themes")	// dir picker popup label
		);

	m_ComboBox->SetFont( pxGetFixedFont( m_ComboBox->GetFont().GetPointSize()+1 ) );
	m_ComboBox->SetMinSize( wxSize( wxDefaultCoord, std::max( m_ComboBox->GetMinSize().GetHeight(), 96 ) ) );

	if (InstallationMode != InstallMode_Portable)
		m_FolderPicker->SetStaticDesc( _("Click the Browse button to select a different folder containing PCSX2 visual themes.") );

	wxButton* refreshButton = new wxButton( this, wxID_ANY, _("Refresh list") );

	*this	+= Label(_("Select a visual theme:"));
	*this	+= m_ComboBox		| StdExpand();
	*this	+= refreshButton	| pxBorder(wxLEFT, StdPadding);
	*this	+= 8;
	*this	+= m_FolderPicker	| StdExpand();

	Bind(wxEVT_BUTTON, &ThemeSelectorPanel::OnRefreshSelections, this, refreshButton->GetId());
}

Panels::ThemeSelectorPanel::~ThemeSelectorPanel() throw ()
{
}

void Panels::ThemeSelectorPanel::Apply()
{
	
}

void Panels::ThemeSelectorPanel::AppStatusEvent_OnSettingsApplied()
{

}

bool Panels::ThemeSelectorPanel::ValidateEnumerationStatus()
{
	bool validated = true;

	// Impl Note: unique_ptr used so that resources get cleaned up if an exception
	// occurs during file enumeration.
	std::unique_ptr<wxArrayString> themelist(new wxArrayString());

	if( m_FolderPicker->GetPath().Exists() )
	{
		wxDir::GetAllFiles(m_FolderPicker->GetPath().ToString(), themelist.get(), L"*.zip;*.p2ui", wxDIR_FILES);
		wxDir::GetAllFiles(m_FolderPicker->GetPath().ToString(), themelist.get(), L"*.*", wxDIR_DIRS);
	}

	if( !m_ThemeList || (*themelist != *m_ThemeList) )
		validated = false;

	m_ThemeList.swap(themelist);

	return validated;
}

void Panels::ThemeSelectorPanel::DoRefresh()
{
	if( !m_ThemeList ) return;

	m_ComboBox->Clear();

	const wxFileName right( g_Conf->FullpathToBios() );

	for( size_t i=0; i<m_ThemeList->GetCount(); ++i )
	{
		wxString description;
		//if( !IsBIOS((*m_BiosList)[i], description) ) continue;
		
		//wxZipInputStream woot;

		int sel = m_ComboBox->Append( description, (void*)i );

		if( wxFileName((*m_ThemeList)[i] ) == right )
			m_ComboBox->SetSelection( sel );
	}
}
