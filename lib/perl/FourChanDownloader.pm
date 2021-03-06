package FourChanDownloader;

use HTML::TreeBuilder;  # must be installed
use LWP::Simple;        # must be installed
use Data::Dumper;
use Try::Tiny;          # must be installed 

=documentation
short description: a module which downloads the files from 4chan threads

Usage
-create a new object with the desired options for download using the new() method 
-call the DownloadThreadImages method with a link to the thread to download it's attachments

Error handling
-This module uses the "die" mechanism. The first 5 characters are always the error code.

Error codes
-ER010 cloud not find the thread. This means that the link was invalid. This should be the only common error to be seen.(For example typo, the thread may have been deleted etc)
-ER011 cloud not fetch a file and save file. Some reasons why this may happen: Attachment was deleted, you don't have enough space etc
-ER012 cloud not create directory - in the rare case when this happens you probablly don't have permissions

Next steps
TODO don't redownload old pictures
=cut
our $VERSION = 0.01;

=documentation
constructor

@param $settings - hashref which contains as keys the options that you want to set
Possible options:
directory_create - boolean if a directory should be created to store the files there
directory_name - string which sets the name of the dir in which the files will be created. If it isn't set and directory_create is true the name will be thread name.
timestamp - boolean if set to true the second from epoch will be added infront of the directory name
identifier - string determines what will replace the space characters. Default is '_'
root_dir the directory root. By default it's the current working directory.

=cut

sub new($;$)
{
    my ($class, $settings) = @_;

    my $self =  {
                    directory_create    => 1,
                    directory_name      => undef,
                    timestamp           => 0,
                    identifier          => '_',
                    root_dir            => '',
                };
    for my $key (keys %$self)
    {
        if(defined $$settings{$key})
        {
            $$self{$key} = $$settings{$key};
        }
    }
    $$self{identifier}  = '_';


    bless $self, $class;
    return $self;
}

=documentation
Downloads the images of a thread. Where they go depend on the settings of the object.

@param $thread_url - the url of the thread

=cut

sub DownloadThreadImages($$)
{
    my ($self, $thread_url) = @_;

    my $tree;
    try
    {
        $tree = HTML::TreeBuilder->new_from_url($thread_url);
    }
    catch
    {
        die "ER010 Error fetching page!\n";
    };

    my $directory_name= "";
    #prettify the title
    my @title = $tree->look_down(_tag => 'title', sub{  my $title_content = $_[0]->content();
                                                        $directory_name = $$title_content[0];
                                                        $directory_name =~ s/\s/$$self{identifier}/g;
                                                        $directory_name =~ s/\///g;}
                                );

    my $save_file_path = ""; 
    my $time_stamp = "";
    if($$self{directory_create})
    {   
        if(defined $$self{directory_name})
        {   
            $directory_name = $$self{directory_name};
        }   
        if($$self{timestamp})
        {   
            $time_stamp = time;
        }            
        my $dir_path =  "$$self{root_dir}$time_stamp$$self{identifier}";
        if( !-d "$dir_path$directory_name" )
        {   
            mkdir "$dir_path$directory_name" or die "ER012 cloud not create directory! $!\n";
        }
        $save_file_path = "$dir_path$directory_name/";
    }
    else
    {
        $$self{directory_name} = "";
    }
    my $saved_files;
    opendir $saved_files, "$dir_path$directory_name" or die "cannot open dir $dir: $!";
    my @file = readdir $saved_files;
    closedir $saved_files;
    print Dumper @file;
    my @elements = $tree->look_down(
                                    _tag  => 'a',
                                    class => 'fileThumb',
                                    #this function is ran for every image.
                                    sub {
                                            my $file_url = 'http:'.$_[0]->attr('href');
                                            print $file_url, "\n";

                                            my @arr = split('/', $file_url);
                                            my $file_name = pop(@arr);
                                            print "File name is: $file_name\n";
                                            for my $saved_file (@saved_files)
                                            {
                                                if($saved_file eq "$save_file_path$file_name")
                                                {
                                                    next;
                                                }
                                            }
                                            try
                                            {
                                                getstore($file_url, "$save_file_path$file_name");
                                            }
                                            catch
                                            {
                                                die "ER011 Error fetching file!";
                                            };
                                        }
                                );
}

sub DownloadImagesMonitor($$$)
{
    my ($self, $thread_url, $sleep_time) = @_;

    if(!defined $sleep_time)
    {
        $sleep_time = 30;
    }
    while(1)
    {
        $self->DownloadImages($thread_url);
        sleep $sleep_time;
    }
}


1;
