#!/usr/bin/perl -w
use 5.012;

################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2007 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WebworkClient.pm,v 1.1 2010/06/08 11:46:38 gage Exp $
# 
# This program is free software; you can redistribute it and/or modify it under
# the terms of either: (a) the GNU General Public License as published by the
# Free Software Foundation; either version 2, or (at your option) any later
# version, or (b) the "Artistic License" which comes with this package.
# 
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See either the GNU General Public License or the
# Artistic License for more details.
################################################################################

=head1 NAME

lib/WeBWorK/Utils/AttemptsTable.pm

This file contains subroutines for formatting the table which reports the 
results of a student's attempt on a WeBWorK question.

=cut

use strict;
use warnings;
package WeBWorK::Utils::AttemptsTable;
use Class::Accessor 'antlers';
use Scalar::Util 'blessed';
use CGI;

# has answers     => (is => 'ro');
# has displayMode =>(is =>'ro');
# has imgGen      => (is =>'ro');

# Object contains hash of answer results
# Object contains display mode
# Object contains or creates Image generator
# object returns table
# object returns color map for answer blanks
# javaScript for handling the color map????


sub new {
	my $class = shift;
	$class = (ref($class))? ref($class) : $class; # create a new object of the same class
	my $rh_answers = shift;
	ref($rh_answers) =~/HASH/ or die "The first entry to AttemptsTable must be a hash of answers";
	my %options = @_; # optional:  displayMode=>, submitted=>, imgGen=>, ce=> 
	my $self = {
		answers      		=> $rh_answers,
		answerOrder         => $options{answerOrder}//(),
		answersSubmitted    => $options{answersSubmitted}//0,
		summary             => $options{summary}//'', # summary provided by problem grader
	    displayMode 		=> $options{displayMode} || "MathJax",
	    #showAttemptAnswers =>  # answers are always shown         # show student answer as entered and simplified 
	                                                               #  (e.g numerical formulas are calculated to produce numbers)
	    showAttemptPreviews => $options{showAttemptPreviews}//1,   # show preview of student answer
	    showAttemptResults 	=> $options{showAttemptResults}//1,    # show whether student answer is correct
	    showMessages 		=> $options{showMessages}//1,          # show any messages generated by evaluation
	    showCorrectAnswers  => $options{showCorrectAnswers}//1,    # show the correct answers
	    showSummary         => $options{showSummary}//1,           # show summary to students
	    maketext            => $options{maketext}//sub {return @_},  # pointer to the maketext subroutine
	    imgGen              => undef,                              # created in _init method
	};
	bless $self, $class;
	# create accessors/mutators
	$self->mk_ro_accessors(qw(answers answerOrder answersSubmitted displayMode imgGen maketext));
	$self->mk_accessors(qw(correct_ids incorrect_ids showMessages));
	$self->mk_ro_accessors(qw(showAttemptPreviews showAttemptResults showCorrectAnswers showSummary));
	# sanity check and initialize imgGenerator.
	_init($self, %options);
	return $self;
}

sub _init {
	# verify display mode
	# build imgGen if it is not supplied 
	my $self = shift;
	my %options = @_;
	$self->{submitted}=$options{submitted}//0;
	$self->{displayMode} = $options{displayMode} || "MathJax";
	# only show message column if there is at least one message:
	my @reallyShowMessages =  grep { $self->answers->{$_}->{ans_message} } @{$self->answerOrder};
	$self->showMessages( $self->showMessages && !!@reallyShowMessages );  
	                               #           (!! forces boolean scalar environment on list)
	
	if ( $self->displayMode eq 'images') {
		if ( blessed( $options{imgGen} ) ) {
			$self->{imgGen} = $options{imgGen};
		} elsif ( blessed( $options{ce} ) ) {
			warn "building imgGen"; 
			my $ce = $options{ce};
			my $site_url = $ce->{server_root_url};	
			my %imagesModeOptions = %{$ce->{pg}->{displayModeOptions}->{images}};
	
			my $imgGen = WeBWorK::PG::ImageGenerator->new(
				tempDir         => $ce->{webworkDirs}->{tmp},
				latex	        => $ce->{externalPrograms}->{latex},
				dvipng          => $ce->{externalPrograms}->{dvipng},
				useCache        => 1,
				cacheDir        => $ce->{webworkDirs}->{equationCache},
				cacheURL        => $site_url.$ce->{webworkURLs}->{equationCache},
				cacheDB         => $ce->{webworkFiles}->{equationCacheDB},
				dvipng_align    => $imagesModeOptions{dvipng_align},
				dvipng_depth_db => $imagesModeOptions{dvipng_depth_db},
			);
	        $self->{imgGen} = $imgGen;
		} else {
			warn "Must provide image Generator (imgGen) or a course environment (ce) to build attempts table.";
		}
	}
}

sub maketext {
	my $self = shift;
	return &{$self->{maketext}}(@_);
}
sub formatAnswerRow {
	my $self          = shift;
	my $rh_answer     = shift;
	my $answerNumber  = shift;
	my $answerString  = $rh_answer->{original_student_ans}||'&nbsp;';
	my $answerPreview = $self->previewAnswer($rh_answer)||'&nbsp;';
	my $correctAnswer = $self->previewCorrectAnswer($rh_answer)||'&nbsp;';
	
	my $answerMessage   = $rh_answer->{ans_message}||'';
	my $feedbackMessageClass = ($answerMessage eq "") ? "" : $self->maketext("FeedbackMessage");
	
	my $score         = (($rh_answer->{type}//'') eq 'essay') ?
						CGI::td({class => "UngradedResults"},$self->maketext("Not graded")): 
						  ($rh_answer->{score}) ? 
							CGI::td({class => "ResultsWithoutError"},$self->maketext("Correct")) :
							CGI::td({class => "ResultsWithError"},$self->maketext("Incorrect"));
	
	my $row = join('',
			  CGI::td({},$answerNumber) ,
			  CGI::td({},$answerString) ,   # student original answer
			  ($self->showAttemptPreviews)?  CGI::td({},$answerPreview):"" ,
			  ($self->showAttemptResults)?  $score :"" ,
			  ($self->showCorrectAnswers)?  CGI::td({},$correctAnswer):"" ,
			  ($self->showMessages)?        CGI::td({class=>$feedbackMessageClass},$self->nbsp($answerMessage)):"",
			  "\n"
			  );
	$row;
}

#####################################################
# determine whether any answers were submitted
# and create answer template if they have been
#####################################################

sub answerTemplate {
	my $self = shift;
	my $rh_answers = $self->{answers};
	my @tableRows;
	my @correct_ids;
	my @incorrect_ids;

	push @tableRows,CGI::Tr(
			CGI::th("#"),
			CGI::th($self->maketext("Answer")),  # student original answer
			($self->showAttemptPreviews)? CGI::th($self->maketext("Preview")):'',
			($self->showAttemptResults)?  CGI::th($self->maketext("Result")):'',
			($self->showCorrectAnswers)?  CGI::th($self->maketext("Correct Answer")):'',
			($self->showMessages)?        CGI::th($self->maketext("Message")):'',
		);

	my $answerNumber     = 1;
    foreach my $ans_id (@{ $self->answerOrder() }) {  
    	push @tableRows, CGI::Tr($self->formatAnswerRow($rh_answers->{$ans_id}, $answerNumber++));
    	push @correct_ids,   $ans_id if $rh_answers->{$ans_id}->{score} >= 1;
    	push @incorrect_ids,   $ans_id if $rh_answers->{$ans_id}->{score} < 1;
    }
	my $answerTemplate = CGI::h3($self->maketext("Results for this submission")) .
    	CGI::table({class=>"attemptResults"},@tableRows);
    $answerTemplate .= ($self->showSummary)? $self->createSummary() : '';
    $answerTemplate = "" unless $self->answersSubmitted; # only print if there is at least one non-blank answer
    $self->correct_ids(\@correct_ids);
    $self->incorrect_ids(\@incorrect_ids);
    $answerTemplate;
}
#################################################

sub previewAnswer {
	my $self =shift;
	my $answerResult = shift;
	my $displayMode = $self->displayMode;
	my $imgGen      = $self->imgGen;
	
	# note: right now, we have to do things completely differently when we are
	# rendering math from INSIDE the translator and from OUTSIDE the translator.
	# so we'll just deal with each case explicitly here. there's some code
	# duplication that can be dealt with later by abstracting out dvipng/etc.
	
	my $tex = $answerResult->{preview_latex_string};
	
	return "" unless defined $tex and $tex ne "";
	
	if ($displayMode eq "plainText") {
		return $tex;
	} elsif (($answerResult->{type}//'') eq 'essay') {
	    return $tex;
	} elsif ($displayMode eq "images") {
		$imgGen->add($tex);
	} elsif ($displayMode eq "MathJax") {
		return '<span class="MathJax_Preview">[math]</span><script type="math/tex; mode=display">'.$tex.'</script>';
	}
}

sub previewCorrectAnswer {
	my $self =shift;
	my $answerResult = shift;
	my $displayMode = $self->displayMode;
	my $imgGen      = $self->imgGen;
	
	my $tex = $answerResult->{correct_ans_latex_string};
	return $answerResult->{correct_ans} unless defined $tex and $tex=~/\S/;   # some answers don't have latex strings defined
	# return "" unless defined $tex and $tex ne "";
	
	if ($displayMode eq "plainText") {
		return $tex;
	} elsif ($displayMode eq "images") {
		$imgGen->add($tex);
		# warn "adding $tex";
	} elsif ($displayMode eq "MathJax") {
		return '<span class="MathJax_Preview">[math]</span><script type="math/tex; mode=display">'.$tex.'</script>';
	}
}

###########################################
# Create summary
###########################################
sub createSummary {
	my $self = shift;
	my $summary = ""; 
	my $numCorrect = 0;
	my $numBlanks  =0;
	my $numEssay = 0;
	my $fully = '';    #FIXME -- find out what this is used for in maketext.
	unless (defined($self->{summary}) and $self->{summary} =~ /\S/) {
		my @answerNames = @{$self->answerOrder()};
		if (scalar @answerNames == 1) {  #default messages
				if ($numCorrect == scalar @answerNames) {
					$summary .= CGI::div({class=>"ResultsWithoutError"},$self->maketext("The answer above is correct."));
				} elsif ($self->{essayFlag}) {
				    $summary .= CGI::div($self->maketext("The answer will be graded later.", $fully));
				 } else {
					 $summary .= CGI::div({class=>"ResultsWithError"},$self->maketext("The answer above is NOT [_1]correct.", $fully));
				 }
		} else {
				if ($numCorrect + $numEssay == scalar @answerNames) {
					$summary .= CGI::div({class=>"ResultsWithoutError"},$self->maketext("All of the [_1] answers above are correct.",  $numEssay ? "gradeable":""));
				 } 
				 #unless ($numCorrect + $numBlanks == scalar( @answerNames)) { # this allowed you to figure out if you got one answer right.
				 elsif ($numBlanks + $numEssay != scalar( @answerNames)) {
					$summary .= CGI::div({class=>"ResultsWithError"},$self->maketext("At least one of the answers above is NOT [_1]correct.", $fully));
				 }
				 if ($numBlanks > $numEssay) {
					my $s = ($numBlanks>1)?'':'s';
					$summary .= CGI::div({class=>"ResultsAlert"},$self->maketext("[quant,_1,of the questions remains,of the questions remain] unanswered.", $numBlanks));
				 }
		}
	} else {
		$summary = $self->{summary};   # summary has been defined by grader
	}

	$summary = CGI::div({role=>"alert", class=>"attemptResultsSummary"},
			  $summary);
	return $summary;
}
################################################


sub color_answer_blanks {
	 my $self = shift;
	 my $out = join('', 
	 		  CGI::start_script({type=>"text/javascript"}),
	            "addOnLoadEvent(function () {color_inputs([\n  ",
		      join(",\n  ",map {"'$_'"} @{$self->{correct_ids}||[]}),
	            "\n],[\n  ",
		      join(",\n  ",map {"'$_'"} @{$self->{incorrect_ids}||[]}),
	            "]\n)});",
	          CGI::end_script()
	);
	return $out;
}

############################################
# utility subroutine -- prevents unwanted line breaks
############################################
sub nbsp {
	my ($self, $str) = @_;
	return (defined $str && $str =~/\S/) ? $str : "&nbsp;";
}



1;
