from django.views.generic import TemplateView
from backend.api import LogLine, Act
import redis

class TranscriptView(TemplateView):
    """
    Base view for all views which deal with transcripts.
    Provides some nice common functionality.
    """

    def parse_mission_time(self, mission_time):
        "Parses a mission timestamp from a URL and converts it to a number of seconds"
        d, h, m, s = [ int(x) for x in mission_time.split(':') ]
        return s + m*60 + h*3600 + d*86400

class PageView(TranscriptView):
    """
    Shows a single page of transcript, based on a passed-in timestamp.
    """

    template_name = 'transcripts/page.html'

    def get_context_data(self, timestamp):
        redis_conn = redis.Redis()

        acts = list(Act.Query(redis_conn, 'a13').items())
        if timestamp is None:
            timestamp = acts[0].start
        else:
            timestamp = self.parse_mission_time(timestamp)

        closest_log_line = LogLine.Query(redis_conn, 'a13').first_after(timestamp)
        page_number = closest_log_line.page
        log_lines = list(LogLine.Query(redis_conn, 'a13').transcript('a13/TEC').page(page_number))

        # Find the previous log line from this, and then the beginning of its page
        try:
            previous_timestamp = LogLine.Query(redis_conn, 'a13').transcript('a13/TEC').page(page_number - 1).first().timestamp
        except ValueError:
            previous_timestamp = None

        # Find the next log line and its timestamp
        next_log_line = log_lines[-1].next()
        if next_log_line:
            next_timestamp = next_log_line.timestamp
        else:
            next_timestamp = None

        return {
            'page_number': page_number,
            'log_lines': log_lines,
            'next_timestamp': next_timestamp,
            'previous_timestamp': previous_timestamp,
            'acts': acts,
            'current_act': log_lines[0].act(),
        }


class PhasesView(TranscriptView):
    """
    Shows the list of all phases (acts).
    """
    
    template_name = 'transcripts/phases.html'
    
    def get_context_data(self):
        redis_conn = redis.Redis()
        return {
            'acts': list(Act.Query(redis_conn, 'a13').items()),
        }


class RangeView(PageView):
    """
    Shows records between two timestamps.
    """
    pass

