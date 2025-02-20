package Koha::Plugin::EDS;

#/*
#=============================================================================================
#* WIDGET NAME: Koha EDS Integration Plugin
#* DESCRIPTION: Integrates EDS with Koha
#* KEYWORDS: Koha, ILS, Integration, API, EDS
#* CUSTOMER PARAMETERS: None
#* EBSCO PARAMETERS: None
#* URL: N/A
#* AUTHOR & EMAIL: Alvet Miranda - amiranda@ebsco.com
#* DATE ADDED: 31/10/2013
#* DATE MODIFIED: 01/Jul/2015
#* LAST CHANGE DESCRIPTION: Updated to 3.1640
#* 							--
#=============================================================================================
#*/

use Modern::Perl; 
use base qw(Koha::Plugins::Base);
use C4::Context;
use C4::Branch;
use C4::Members;
use C4::Auth;
use Cwd            qw( abs_path );
use File::Basename qw( dirname );
use JSON qw/decode_json encode_json/;
use Try::Tiny;
use IO::Socket::SSL qw();
use WWW::Mechanize qw(); 
my $mech = WWW::Mechanize->new(ssl_opts => {
    SSL_verify_mode => IO::Socket::SSL::SSL_VERIFY_NONE,
    verify_hostname => 0,
});


my $PluginDir = C4::Context->config("pluginsdir");
$PluginDir = $PluginDir.'/Koha/Plugin/EDS';

## Here we set our plugin version
our $VERSION = 3.1640;

## Here is our metadata, some keys are required, some are optional
our $metadata = {
    name   => 'Koha EDS API Integration',
    author => 'Alvet Miranda - amiranda@ebsco.com',
    description =>
'This plugin integrates EBSCO Discovery Service(EDS) in Koha.<p>Go to Run tool (left) for setup instructions and then Configure(right) to configure the API Plugin.</p><p>More information is available at the <a href="https://github.com/ebsco/edsapi-koha-plugin" target="_blank"> plugin site on GitHub</a>. <br> For assistance; visit email EBSCO support at <a href="mailto:support@ebscohost.com">support@ebsco.com</a> or call the toll free international hotline at +800-3272-6000</p>',
    date_authored   => '2013-10-27',
    date_updated    => '2015-07-01',
    minimum_version => '3.16',
    maximum_version => '',
    version         => $VERSION,
};

## This is the minimum code required for a plugin's 'new' method
## More can be added, but none should be removed
sub new {
    my ( $class, $args ) = @_;

    ## We need to add our metadata here so our base class can access it
    $args->{'metadata'} = $metadata;

    ## Here, we call the 'new' method for our base class
    ## This runs some additional magic and checking
    ## and returns our actual $self
    my $self = $class->SUPER::new($args);

    return $self;
}

sub tool {
    my ( $self, $args ) = @_;

    my $cgi = $self->{'cgi'};

    unless ( $cgi->param('submitted') ) {
        $self->SetupTool();
    }


}

## Logic for configure method
sub configure {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    unless ( $cgi->param('save') ) {
        my $template = $self->get_template({ file => 'admin/configure.tt' });

        ## Grab the values we already have for our settings, if any exist
        $template->param(
			edsusername 		=> $self->retrieve_data('edsusername'),
			edspassword 		=> $self->retrieve_data('edspassword'),
			edsprofileid 		=> $self->retrieve_data('edsprofileid'),
			edscustomerid 		=> $self->retrieve_data('edscustomerid'),
			cataloguedbid 		=> $self->retrieve_data('cataloguedbid'),
			catalogueanprefix 	=> $self->retrieve_data('catalogueanprefix'),
			defaultsearch 		=> $self->retrieve_data('defaultsearch'),
			cookieexpiry 		=> $self->retrieve_data('cookieexpiry'),
			logerrors			=> $self->retrieve_data('logerrors'),
			edsinfo				=> $self->retrieve_data('edsinfo'),
			lastedsinfoupdate	=> $self->retrieve_data('lastedsinfoupdate'),
			authtoken			=> $self->retrieve_data('authtoken'),
			OPACBaseURL			=> C4::Context->preference('OPACBaseURL'),		
			edsswitchtext	=> $self->retrieve_data('edsswitchtext'),
			kohaswitchtext	=> $self->retrieve_data('kohaswitchtext'),
			edsselecttext	=> $self->retrieve_data('edsselecttext'),
			edsselectinfo	=> $self->retrieve_data('edsselectinfo'),
			kohaselectinfo	=> $self->retrieve_data('kohaselectinfo'),
			defaultparams	=> $self->retrieve_data('defaultparams'),
			instancepath	=> $self->retrieve_data('instancepath'),
			
			
        );

        print $cgi->header();
        print $template->output();
    }
    else {
		
		$self->store_data(
				{
					edsusername 		=> ($cgi->param('edsusername')?$cgi->param('edsusername'):"-"),
					edspassword 		=> ($cgi->param('edspassword')?$cgi->param('edspassword'):"-"),
					edsprofileid 		=> ($cgi->param('edsprofileid')?$cgi->param('edsprofileid'):"-"),
					edscustomerid 		=> ($cgi->param('edscustomerid')?$cgi->param('edscustomerid'):"-"),
					cataloguedbid 		=> ($cgi->param('cataloguedbid')?$cgi->param('cataloguedbid'):"-"),
					catalogueanprefix 	=> ($cgi->param('catalogueanprefix')?$cgi->param('catalogueanprefix'):"-"), 
					defaultsearch 		=> ($cgi->param('defaultsearch')?$cgi->param('defaultsearch'):"-"),
					logerrors			=> ($cgi->param('logerrors')?$cgi->param('logerrors'):"-"),
					cookieexpiry 		=> ($cgi->param('cookieexpiry')?$cgi->param('cookieexpiry'):"-"),
					last_configured_by => C4::Context->userenv->{'number'},
					edsswitchtext	=> ($cgi->param('edsswitchtext')?$cgi->param('edsswitchtext'):"-"),
					kohaswitchtext	=> ($cgi->param('kohaswitchtext')?$cgi->param('kohaswitchtext'):"-"),
					edsselecttext	=> ($cgi->param('edsselecttext')?$cgi->param('edsselecttext'):"-"),
					edsselectinfo	=> ($cgi->param('edsselectinfo')?$cgi->param('edsselectinfo'):"-"),
					kohaselectinfo	=> ($cgi->param('kohaselectinfo')?$cgi->param('kohaselectinfo'):"-"),
					defaultparams	=> ($cgi->param('defaultparams')?$cgi->param('defaultparams'):"-"),
					instancepath	=> ($cgi->param('instancepath')?$cgi->param('instancepath'):"-"),
				}
			);
		
			if($cgi->param('edsinfo') eq 'Update Required'){ 
				
				$self->store_data(
					{
						authtoken 			=> $cgi->param('authtoken'), 
						lastedsinfoupdate	=> $cgi->param('lastedsinfoupdate'),
						edsinfo 			=> $cgi->param('edsinfo'),
						$self->store_data
					}
				);	

			}
        $self->go_home();
    }
}


sub install() {
    my ( $self, $args ) = @_;
##Leaving this code incase this plugin needs its own table in the future
#    my $table = $self->get_qualified_table_name('config');

#    return C4::Context->dbh->do( "
#		CREATE TABLE $table (
#		`edsid` INT NOT NULL AUTO_INCREMENT,
#		`edskey` VARCHAR(100) NOT NULL,
#		`edsvalue` TEXT NOT NULL, 
#		PRIMARY KEY (`edsid`)) ENGINE = INNODB;
#    " ); 

	
	
	my $enableEDS = C4::Context->dbh->do("INSERT INTO `systempreferences` (`variable`, `value`, `explanation`, `type`) VALUES ('EDSEnabled', '1', 'If ON, enables searching with EDS - Plugin required.For assistance; email EBSCO support at support\@ebscohost.com', 'YesNo') ON DUPLICATE KEY UPDATE `variable`='EDSEnabled', `value`=1, `explanation`='If ON, enables searching with EDS - Plugin required.For assistance; email EBSCO support at support\@ebscohost.com', `type`='YesNo'");
	
	
	my $enableEDSUpdate = C4::Context->dbh->do("UPDATE `systempreferences` SET `value`='1' WHERE `variable`='EDSEnabled'");
	
	my $pluginSQL = C4::Context->dbh->do("INSERT INTO `plugin_data` (`plugin_class`, `plugin_key`, `plugin_value`) VALUES ('Koha::Plugin::EDS', 'installedversion', '".$VERSION."')");
	#use Data::Dumper; die Dumper $pluginSQL;		
}




sub uninstall() {
    my ( $self, $args ) = @_;
##Leaving this code incase this plugin needs its own table in the future
#    my $table = $self->get_qualified_table_name('config');

#    return C4::Context->dbh->do("DROP TABLE $table");
	my $enableEDS = C4::Context->dbh->do("INSERT INTO `systempreferences` (`variable`, `value`, `explanation`, `type`) VALUES ('EDSEnabled', '0', 'If ON, enables searching with EDS - Plugin required.For assistance; email EBSCO support at support\@ebscohost.com', 'YesNo') ON DUPLICATE KEY UPDATE `variable`='EDSEnabled', `value`=1, `explanation`='If ON, enables searching with EDS - Plugin required.For assistance; email EBSCO support at support\@ebscohost.com', `type`='YesNo'");
	
	my $enableEDSUpdate = C4::Context->dbh->do("UPDATE `systempreferences` SET `value`='0' WHERE `variable`='EDSEnabled'");
}

sub PageURL{
	# http://stackoverflow.com/questions/3412280/how-do-i-obtain-the-current-url-in-perl
	my $page_url = 'http';
	if ($ENV{HTTPS} = "on") {
		#$page_url .= "s";
	}
	$page_url .= "://";
	if ($ENV{SERVER_PORT} != "80") {
		$page_url .= $ENV{SERVER_NAME}.":".$ENV{SERVER_PORT}.$ENV{REQUEST_URI};
	} else {
		$page_url .= $ENV{SERVER_NAME}.$ENV{REQUEST_URI};
	}	
	
	return $page_url;
	
}

sub SetupTool {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};
	
	###BEGIN UpdatePlugin
	
	my $updateSHA = $cgi->param('updateto');
	my $updateVersion = $cgi->param('v');
	my $checkFile = $cgi->param('check');
	my $customJS = $cgi->param('js');
	my $jsCode = $cgi->param('code');

	
	my $updateLog = '';
	my $readWriteStatus = '';
	my @customJSContent;
	
	if(defined $checkFile){
		require $PluginDir.'/admin/setuptool.pl';
		$readWriteStatus = CheckWriteStatus($checkFile);
	}
	
	if(defined $customJS){
		require $PluginDir.'/admin/setuptool.pl';
		
		if($customJS eq "2"){
			SetCustomJS($jsCode);	
		}
		
		@customJSContent = GetCustomJS();
		#use Data::Dumper; die Dumper scalar(@customJSContent);
		if(scalar(@customJSContent) eq 0){
			push(@customJSContent,'//Enter JavaScript here');
		}
		
	}
		
	if(defined $updateSHA){
		if($updateSHA ne 'done'){
			require $PluginDir.'/admin/setuptool.pl';
			$updateLog = UpdateEDSPlugin($updateSHA);
			my $updateInstalledVersion = C4::Context->dbh->do("UPDATE `plugin_data` SET `plugin_value`='".$updateVersion."' WHERE `plugin_class`='Koha::Plugin::EDS' and `plugin_key`='installedversion'");

		}
	}
	
	###END UpdatePlugin
	
	### Setup installed version no. in plugin table if this was not set during installation.
	my $installedVersionNo = $self->retrieve_data('installedversion');
	if(not defined $installedVersionNo){
		
		$self->store_data(
		{
			installedversion 		=> $VERSION,
		});
		$self->go_home();
	
	} 
	
	
	## Pull SHA data for version info.
	my $shaData = '';
	try{
		$mech->get('https://widgets.ebscohost.com/prod/api/koha/sha/316.json');
		$shaData= $mech->content();
		$shaData=decode_json($shaData);
	}catch{
		$shaData=decode_json('{"edsplugin": {"version": [{"number": "3.1636","sha": "9a10c2acfca0a4c7e13d74dd9dca4ff117b28a0e"}]}}');
	};
	$mech->get('https://cdn.rawgit.com/ebsco/edsapi-koha-plugin/'.$shaData->{edsplugin}->{version}[0]->{sha}.'/Koha/Plugin/EDS/admin/release_notes.xml');
	my $xmlReleaseNotes = $mech->content();
	#use Data::Dumper; die Dumper $xmlReleaseNotes;

	my $currentVersion ="<select id='liveupdate-version'>";

	my @pluginVersions = @{$shaData->{edsplugin}->{version}};

	foreach my $pluginVersion (@pluginVersions){
			my $selectedVersion="";
			if($self->retrieve_data('installedversion') eq $pluginVersion->{number}){
				$selectedVersion=" selected='selected'";
			}
			$currentVersion .="<option value='".$pluginVersion->{sha}."'".$selectedVersion.">";
			$currentVersion .=$pluginVersion->{number};
			$currentVersion .="</option>";
	}


	$currentVersion .="</select>";


    my $template = $self->get_template({ file => 'admin/setuptool.tt' });
	        $template->param(
			edsusername 		=> $self->retrieve_data('edsusername'),
			edspassword 		=> $self->retrieve_data('edspassword'),
			pluginversion		=> $VERSION,
			installedversion	=> $currentVersion,
			latestversion		=>$shaData->{edsplugin}->{version}[0]->{number},
			releasenotes		=>$xmlReleaseNotes,
			updatelog			=>$updateLog,
			readwritestatus		=>$readWriteStatus,
			customjs			=>\@customJSContent,
			jsstate				=>$customJS,
			plugin_dir			=>$PluginDir,
				
        );

    print $cgi->header();
    print $template->output();
}
1;