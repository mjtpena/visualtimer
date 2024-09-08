import React, { useState, useRef, useEffect } from 'react';
import { View, StyleSheet, TextInput, TouchableOpacity, Text, ViewStyle, TextStyle } from 'react-native';
import Svg, { Circle, G, Text as SvgText, Path, Line } from 'react-native-svg';
import { Feather } from '@expo/vector-icons';
import { Audio } from 'expo-av';

type ClockSize = 'small' | 'medium' | 'large';

const VisualTimerScreen: React.FC = () => {
    const [timeLeft, setTimeLeft] = useState<number>(0);
    const [isRunning, setIsRunning] = useState<boolean>(false);
    const [inputMinutes, setInputMinutes] = useState<string>('');
    const [inputSeconds, setInputSeconds] = useState<string>('');
    const [isDarkMode, setIsDarkMode] = useState<boolean>(false);
    const [showInput, setShowInput] = useState<boolean>(true);
    const [clockSize, setClockSize] = useState<ClockSize>('medium');
    const [isMinutesFocused, setIsMinutesFocused] = useState<boolean>(false);
    const [isSecondsFocused, setIsSecondsFocused] = useState<boolean>(false);
    const [isFlipped, setIsFlipped] = useState<boolean>(false);
    const [isSoundOn, setIsSoundOn] = useState<boolean>(true);
    const timerRef = useRef<NodeJS.Timeout | null>(null);
    const tickSoundRef = useRef<Audio.Sound | null>(null);
    const loudTickSoundRef = useRef<Audio.Sound | null>(null);
    const timerEndSoundRef = useRef<Audio.Sound | null>(null);

    const CLOCK_SIZES: Record<ClockSize, number> = {
        small: 300,
        medium: 400,
        large: 500
    };

    const CLOCK_SIZE = CLOCK_SIZES[clockSize];
    const TIMER_RADIUS = CLOCK_SIZE / 2 - 20;
    const BORDER_WIDTH = 8;

    useEffect(() => {
        loadSounds();
        return () => {
            unloadSounds();
        };
    }, []);

    const loadSounds = async () => {
        const tickSound = new Audio.Sound();
        const loudTickSound = new Audio.Sound();
        const timerEndSound = new Audio.Sound();
        try {
            console.log('Loading tick sound...');
            await tickSound.loadAsync(require('../assets/tick.wav'));
            console.log('Tick sound loaded successfully');

            console.log('Loading loud tick sound...');
            await loudTickSound.loadAsync(require('../assets/loud-tick.wav'));
            console.log('Loud tick sound loaded successfully');

            console.log('Loading timer end sound...');
            await timerEndSound.loadAsync(require('../assets/timer.wav'));
            console.log('Timer end sound loaded successfully');

            tickSoundRef.current = tickSound;
            loudTickSoundRef.current = loudTickSound;
            timerEndSoundRef.current = timerEndSound;
        } catch (error) {
            console.error('Error loading sounds:', error);
        }
    };

    const unloadSounds = async () => {
        if (tickSoundRef.current) await tickSoundRef.current.unloadAsync();
        if (loudTickSoundRef.current) await loudTickSoundRef.current.unloadAsync();
        if (timerEndSoundRef.current) await timerEndSoundRef.current.unloadAsync();
    };

    const playSound = async (sound: Audio.Sound | null) => {
        try {
            if (sound && isSoundOn) {
                console.log('Attempting to play sound...');
                await sound.replayAsync();
                console.log('Sound played successfully');
            } else {
                console.log('Sound is off or sound object is null, cannot play');
            }
        } catch (error) {
            console.error('Error playing sound:', error);
        }
    };

    useEffect(() => {
        if (isRunning && timeLeft > 0) {
            timerRef.current = setInterval(() => {
                setTimeLeft((prevTime) => {
                    if (prevTime <= 1) {
                        clearInterval(timerRef.current as NodeJS.Timeout);
                        setIsRunning(false);
                        setShowInput(true);
                        console.log('Timer ended, playing end sound');
                        playSound(timerEndSoundRef.current);
                        return 0;
                    }
                    const newTime = prevTime - 1;
                    if (newTime % 300 === 0) {
                        console.log('5-minute mark, playing loud tick');
                        playSound(loudTickSoundRef.current);
                    } else {
                        console.log('Regular tick');
                        playSound(tickSoundRef.current);
                    }
                    return newTime;
                });
            }, 1000);
        } else if (!isRunning && timerRef.current) {
            clearInterval(timerRef.current);
        }
        return () => {
            if (timerRef.current) {
                clearInterval(timerRef.current);
            }
        };
    }, [isRunning, timeLeft, isSoundOn]);

    const handleStartStop = (): void => {
        if (timeLeft > 0) {
            setIsRunning(!isRunning);
            setShowInput(false);
        }
    };

    const handleReset = (): void => {
        setIsRunning(false);
        setTimeLeft(0);
        setShowInput(true);
    };

    const handleInputChange = (text: string, isMinutes: boolean): void => {
        const numericValue = text.replace(/[^0-9]/g, '');
        if (isMinutes) {
            if (numericValue === '' || parseInt(numericValue) <= 60) {
                setInputMinutes(numericValue);
            }
        } else {
            if (numericValue === '' || parseInt(numericValue) < 60) {
                setInputSeconds(numericValue);
            }
        }
    };

    const handleSetTime = (): void => {
        const minutes = parseInt(inputMinutes, 10) || 0;
        const seconds = parseInt(inputSeconds, 10) || 0;
        const totalSeconds = minutes * 60 + seconds;
        if (totalSeconds > 0) {
            setTimeLeft(totalSeconds);
            setInputMinutes('');
            setInputSeconds('');
            setShowInput(false);
        }
    };

    const toggleDarkMode = (): void => {
        setIsDarkMode(!isDarkMode);
    };

    const toggleClockSize = (): void => {
        const sizes: ClockSize[] = ['small', 'medium', 'large'];
        const currentIndex = sizes.indexOf(clockSize);
        const nextIndex = (currentIndex + 1) % sizes.length;
        setClockSize(sizes[nextIndex]);
    };

    const toggleFlip = (): void => {
        setIsFlipped(!isFlipped);
    };

    const toggleSound = (): void => {
        setIsSoundOn(!isSoundOn);
    };

    const formatTime = (seconds: number): string => {
        const mins = Math.floor(seconds / 60);
        const secs = seconds % 60;
        return `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
    };

    const getArcPath = (): string => {
        const startAngle = -90;
        const endAngle = (360 * timeLeft) / 3600 - 90;
        const largeArcFlag = timeLeft > 1800 ? '1' : '0';
        const start = polarToCartesian(CLOCK_SIZE / 2, CLOCK_SIZE / 2, TIMER_RADIUS - BORDER_WIDTH / 2, endAngle);
        const end = polarToCartesian(CLOCK_SIZE / 2, CLOCK_SIZE / 2, TIMER_RADIUS - BORDER_WIDTH / 2, startAngle);
        return [
            'M', start.x, start.y,
            'A', TIMER_RADIUS - BORDER_WIDTH / 2, TIMER_RADIUS - BORDER_WIDTH / 2, 0, largeArcFlag, 0, end.x, end.y,
            'L', CLOCK_SIZE / 2, CLOCK_SIZE / 2,
            'Z'
        ].join(' ');
    };

    const polarToCartesian = (centerX: number, centerY: number, radius: number, angleInDegrees: number): { x: number; y: number } => {
        const angleInRadians = (angleInDegrees) * Math.PI / 180.0;
        return {
            x: centerX + (radius * Math.cos(angleInRadians)),
            y: centerY + (radius * Math.sin(angleInRadians))
        };
    };

    return (
        <View style={[styles.container, isDarkMode && styles.darkMode]}>
            <View style={styles.topButtons}>
                <TouchableOpacity onPress={toggleClockSize} style={styles.iconButton}>
                    <Feather name="maximize" size={24} color={isDarkMode ? "#4DA6FF" : "black"} />
                </TouchableOpacity>
                <TouchableOpacity onPress={toggleFlip} style={styles.iconButton}>
                    <Feather name="repeat" size={24} color={isDarkMode ? "#4DA6FF" : "black"} />
                </TouchableOpacity>
                <TouchableOpacity onPress={toggleSound} style={styles.iconButton}>
                    <Feather
                        name={isSoundOn ? "volume-2" : "volume-x"}
                        size={24}
                        color={isDarkMode ? "#4DA6FF" : "black"}
                    />
                </TouchableOpacity>
                <TouchableOpacity onPress={toggleDarkMode} style={styles.iconButton}>
                    <Feather name={isDarkMode ? "sun" : "moon"} size={24} color={isDarkMode ? "#4DA6FF" : "black"} />
                </TouchableOpacity>
            </View>
            <Svg height={CLOCK_SIZE} width={CLOCK_SIZE}>
                <G transform={isFlipped ? `scale(-1, 1) translate(${-CLOCK_SIZE}, 0)` : ''}>
                    <Circle
                        r={TIMER_RADIUS}
                        cx={CLOCK_SIZE / 2}
                        cy={CLOCK_SIZE / 2}
                        stroke={isDarkMode ? "#FFFFFF" : "#000000"}
                        strokeWidth={BORDER_WIDTH}
                        fill={isDarkMode ? "#333333" : "#FFFFFF"}
                    />
                    <Path
                        d={getArcPath()}
                        fill={isDarkMode ? "#4DA6FF" : "#FF0000"}
                    />
                    {/* Minute marks */}
                    {[...Array(60)].map((_, i) => {
                        const angle = (i * 6 - 90) * Math.PI / 180;
                        const length = i % 5 === 0 ? 15 : 7;
                        return (
                            <Line
                                key={i}
                                x1={CLOCK_SIZE / 2 + (TIMER_RADIUS - length - BORDER_WIDTH / 2) * Math.cos(angle)}
                                y1={CLOCK_SIZE / 2 + (TIMER_RADIUS - length - BORDER_WIDTH / 2) * Math.sin(angle)}
                                x2={CLOCK_SIZE / 2 + (TIMER_RADIUS - BORDER_WIDTH / 2) * Math.cos(angle)}
                                y2={CLOCK_SIZE / 2 + (TIMER_RADIUS - BORDER_WIDTH / 2) * Math.sin(angle)}
                                stroke={isDarkMode ? "#FFFFFF" : "#000000"}
                                strokeWidth={i % 5 === 0 ? 2 : 1}
                            />
                        );
                    })}
                    {/* Donut-shaped center */}
                    <Circle
                        cx={CLOCK_SIZE / 2}
                        cy={CLOCK_SIZE / 2}
                        r={20}
                        fill={isDarkMode ? "#FFFFFF" : "#000000"}
                    />
                    <Circle
                        cx={CLOCK_SIZE / 2}
                        cy={CLOCK_SIZE / 2}
                        r={15}
                        fill={isDarkMode ? "#333333" : "#FFFFFF"}
                    />
                    <Line
                        x1={CLOCK_SIZE / 2}
                        y1={CLOCK_SIZE / 2}
                        x2={polarToCartesian(CLOCK_SIZE / 2, CLOCK_SIZE / 2, TIMER_RADIUS - 40, (360 * timeLeft) / 3600 - 90).x}
                        y2={polarToCartesian(CLOCK_SIZE / 2, CLOCK_SIZE / 2, TIMER_RADIUS - 40, (360 * timeLeft) / 3600 - 90).y}
                        stroke={isDarkMode ? "#FFFFFF" : "#000000"}
                        strokeWidth={6}
                    />
                    {[...Array(12)].map((_, i) => (
                        <SvgText
                            key={i}
                            x={CLOCK_SIZE / 2 + (TIMER_RADIUS - 40) * Math.sin((i * 30) * Math.PI / 180)}
                            y={CLOCK_SIZE / 2 - (TIMER_RADIUS - 40) * Math.cos((i * 30) * Math.PI / 180)}
                            fontSize={CLOCK_SIZE / 15}
                            textAnchor="middle"
                            alignmentBaseline="central"
                            fill={isDarkMode ? "#FFFFFF" : "#000000"}
                            transform={isFlipped ? `scale(-1, 1) translate(${-2 * (CLOCK_SIZE / 2 + (TIMER_RADIUS - 40) * Math.sin((i * 30) * Math.PI / 180))}, 0)` : ''}
                        >
                            {i * 5}
                        </SvgText>
                    ))}
                </G>
            </Svg>
            <Text style={[styles.timerText, isDarkMode && styles.darkModeText]}>{formatTime(timeLeft)}</Text>
            <View style={styles.controls}>
                {showInput && (
                    <View style={styles.inputContainer}>
                        <TextInput
                            style={[
                                styles.input,
                                isDarkMode && styles.darkModeInput,
                                (isMinutesFocused || inputMinutes !== '') && (isDarkMode ? styles.darkModeFocusedInput : styles.focusedInput)
                            ]}
                            onChangeText={(text) => handleInputChange(text, true)}
                            value={inputMinutes}
                            keyboardType="numeric"
                            placeholder="Minutes"
                            placeholderTextColor={isDarkMode ? "#888888" : "#AAAAAA"}
                            onFocus={() => setIsMinutesFocused(true)}
                            onBlur={() => setIsMinutesFocused(false)}
                        />
                        <TextInput
                            style={[
                                styles.input,
                                isDarkMode && styles.darkModeInput,
                                (isSecondsFocused || inputSeconds !== '') && (isDarkMode ? styles.darkModeFocusedInput : styles.focusedInput)
                            ]}
                            onChangeText={(text) => handleInputChange(text, false)}
                            value={inputSeconds}
                            keyboardType="numeric"
                            placeholder="Seconds"
                            placeholderTextColor={isDarkMode ? "#888888" : "#AAAAAA"}
                            onFocus={() => setIsSecondsFocused(true)}
                            onBlur={() => setIsSecondsFocused(false)}
                        />
                        <Text style={[styles.validationText, isDarkMode && styles.darkModeValidationText]}>
                            Enter time (max 60 minutes)
                        </Text>
                    </View>
                )}
                {showInput && (
                    <TouchableOpacity onPress={handleSetTime} style={[styles.iconButton, styles.setButton]}>
                        <Feather name="clock" size={24} color="white" />
                    </TouchableOpacity>
                )}
                {!showInput && (
                    <>
                        <TouchableOpacity onPress={handleStartStop} style={styles.iconButton}>
                            <Feather name={isRunning ? "pause" : "play"} size={24} color={isDarkMode ? "#4DA6FF" : "black"} />
                        </TouchableOpacity>
                        <TouchableOpacity onPress={handleReset} style={styles.iconButton}>
                            <Feather name="stop-circle" size={24} color={isDarkMode ? "#4DA6FF" : "black"} />
                        </TouchableOpacity>
                    </>
                )}
            </View>
        </View>
    );
};

interface Style {
    container: ViewStyle;
    darkMode: ViewStyle;
    topButtons: ViewStyle;
    controls: ViewStyle;
    inputContainer: ViewStyle;
    input: TextStyle;
    darkModeInput: TextStyle;
    focusedInput: TextStyle;
    darkModeFocusedInput: TextStyle;
    iconButton: ViewStyle;
    setButton: ViewStyle;
    timerText: TextStyle;
    darkModeText: TextStyle;
    validationText: TextStyle;
    darkModeValidationText: TextStyle;
}

const styles = StyleSheet.create<Style>({
    container: {
        flex: 1,
        backgroundColor: '#FFFFFF',
        alignItems: 'center',
        justifyContent: 'center',
    },
    darkMode: {
        backgroundColor: '#222222',
    },
    topButtons: {
        flexDirection: 'row',
        position: 'absolute',
        top: 40,
        right: 20,
    },
    controls: {
        flexDirection: 'row',
        marginTop: 20,
        alignItems: 'center',
    },
    inputContainer: {
        alignItems: 'flex-start',
    },
    input: {
        width: 150,
        marginRight: 10,
        fontSize: 16,
        borderBottomWidth: 1,
        borderBottomColor: '#CCCCCC',
        paddingBottom: 5,
    },
    darkModeInput: {
        color: 'white',
        borderBottomColor: '#666666',
    },
    focusedInput: {
        borderBottomColor: '#FF0000',
    },
    darkModeFocusedInput: {
        borderBottomColor: '#4DA6FF',
    },
    iconButton: {
        padding: 10,
        marginHorizontal: 5,
        borderRadius: 8,
        backgroundColor: '#EEEEEE',
    },
    setButton: {
        backgroundColor: '#007AFF',
    },
    timerText: {
        fontSize: 48,
        fontWeight: 'bold',
        marginTop: 20,
    },
    darkModeText: {
        color: 'white',
    },
    validationText: {
        fontSize: 12,
        color: '#888888',
        marginTop: 5,
    },
    darkModeValidationText: {
        color: '#AAAAAA',
    },
});

export default VisualTimerScreen;