import { useEffect, useState } from "react";



export function useBackgroundAudio(audioFile?: string){

    const [bgAudio] = useState<HTMLAudioElement>(new Audio(audioFile || "/assets/bg_dark.mp3"));


    const pause = () => {
        bgAudio.pause();
    }

    const resume = () => {
        bgAudio.play();
    }

    const restart = () => {
        bgAudio.currentTime = 0;
        bgAudio.play();
    }
    
    const handleBgAudioRepeat = (bgAudio: HTMLAudioElement) => {
        bgAudio.currentTime = 0;
        bgAudio.play();
    }
    

    useEffect(() => {
        bgAudio.play();
        bgAudio.addEventListener('ended', () => handleBgAudioRepeat(bgAudio));


        return () => {
            bgAudio.removeEventListener('ended', () => handleBgAudioRepeat(bgAudio));
        }
    }, []);


    return {
        pause,
        resume,
        restart
    }


}
